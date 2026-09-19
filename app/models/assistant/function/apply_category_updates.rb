class Assistant::Function::ApplyCategoryUpdates < Assistant::Function
  include Assistant::Function::CategorizeSupport

  class << self
    def name
      "apply_category_updates"
    end

    def description
      <<~INSTRUCTIONS
        Batch-apply category assignments. Pass updates as
        [{transaction_id, category_id}] or [{transaction_id, category_name}].

        Prefer category_id from get_categories. Max #{Assistant::Function::CategorizeSupport::MAX_UPDATES} updates per
        call. Transactions the user cannot edit, ids from another family, and
        unknown categories are skipped rather than aborting the rest of the batch.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "updates" ],
      properties: {
        updates: {
          type: "array",
          minItems: 1,
          maxItems: Assistant::Function::CategorizeSupport::MAX_UPDATES,
          description: "Array of {transaction_id, category_id} or {transaction_id, category_name}",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              transaction_id: {
                type: "string",
                description: "Transaction ID from list_uncategorized_transactions or get_transactions"
              },
              category_id: {
                type: "string",
                description: "Category ID from get_categories. Preferred over category_name."
              },
              category_name: {
                type: "string",
                description: "Exact category name from get_categories. Used when category_id is omitted."
              }
            }
          }
        }
      }
    )
  end

  def call(params = {})
    updates = Array(params["updates"])
    return error("updates_required", "Provide at least one update.") if updates.empty?
    return error("too_many_updates", "At most #{MAX_UPDATES} updates per call.") if updates.size > MAX_UPDATES

    applied = []
    skipped = []

    updates.each do |raw|
      payload = apply_one(stringify_keys(raw))
      if payload[:ok]
        applied << payload.except(:ok)
      else
        skipped << payload.except(:ok)
      end
    end

    {
      success: skipped.empty?,
      applied_count: applied.size,
      skipped_count: skipped.size,
      applied: applied,
      skipped: skipped,
      message: "Applied #{applied.size} of #{updates.size} category updates."
    }
  end

  private
    def apply_one(item)
      transaction_id = item["transaction_id"].to_s
      return skip(transaction_id, "invalid_transaction", "transaction_id is required.") if transaction_id.blank?

      transaction = find_accessible_transaction(transaction_id)
      return skip(transaction_id, "not_found", "Transaction not found.") unless transaction

      entry = transaction.entry
      unless permitted_to_categorize?(entry.account)
        return skip(transaction_id, "not_authorized", "You do not have permission to categorize this transaction.")
      end

      category, category_error = resolve_category(item)
      return skip(transaction_id, category_error[:error], category_error[:message]) if category_error

      Entry.transaction do
        entry.update!(entryable_attributes: { id: entry.entryable_id, category_id: category.id })
        entry.transaction.record_category_usage!
        entry.lock_saved_attributes!
      end

      {
        ok: true,
        transaction_id: transaction.id,
        category_id: category.id,
        category_name: category.name
      }
    rescue ActiveRecord::RecordInvalid => e
      skip(transaction_id, "validation_failed", e.record.errors.full_messages.join("; "))
    end

    def resolve_category(item)
      if item["category_id"].present?
        return [ nil, { error: "invalid_category", message: "category_id is not a valid id." } ] unless valid_uuid?(item["category_id"])

        category = family.categories.find_by(id: item["category_id"])
        return [ nil, { error: "invalid_category", message: "category_id does not belong to the user's family." } ] unless category

        [ category, nil ]
      elsif item["category_name"].present?
        category = find_category_by_name(item["category_name"])
        return [ nil, { error: "category_not_found", message: "No category named '#{item["category_name"]}'." } ] unless category

        [ category, nil ]
      else
        [ nil, { error: "category_required", message: "Provide category_id or category_name." } ]
      end
    end

    def find_category_by_name(name)
      trimmed = name.to_s.strip
      family.categories.find_by(name: trimmed) ||
        family.categories.find_by("LOWER(name) = ?", trimmed.downcase)
    end

    def stringify_keys(raw)
      return raw.stringify_keys if raw.respond_to?(:stringify_keys)

      {}
    end

    def skip(transaction_id, key, message)
      { ok: false, transaction_id: transaction_id, error: key, message: message }
    end
end
