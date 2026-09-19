class Assistant::Function::CreateRule < Assistant::Function
  class << self
    def name
      "create_rule"
    end

    def description
      <<~INSTRUCTIONS
        Creates a transaction rule that categorizes matching transactions.
        In chat this becomes an approval card — do not claim the rule is saved
        until the user approves it.

        Prefer an exact category_id from get_categories. The condition matches
        transaction names that contain `match_value` (case-insensitive).
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "match_value", "category_id" ],
      properties: {
        name: {
          type: "string",
          description: "Optional display name for the rule"
        },
        match_value: {
          type: "string",
          description: "Transaction name fragment to match (contains)"
        },
        category_id: {
          type: "string",
          description: "Category ID from get_categories"
        },
        transaction_type: {
          type: "string",
          enum: [ "income", "expense", "transfer" ],
          description: "Optional type filter"
        }
      }
    )
  end

  def call(params = {})
    match_value = params["match_value"].to_s.strip.presence || params["value"].to_s.strip
    return error("match_value_required", "Provide match_value.") if match_value.blank?

    category_id = params["category_id"].presence || params["action_value"].presence
    return error("category_required", "Provide category_id.") unless valid_uuid?(category_id)

    category = family.categories.find_by(id: category_id)
    return error("invalid_category", "category_id does not belong to the user's family.") unless category

    rule = family.rules.build(
      name: params["name"].presence || match_value,
      resource_type: "transaction",
      active: false
    )
    rule.conditions.build(condition_type: "transaction_name", operator: "like", value: match_value)
    if params["transaction_type"].present?
      rule.conditions.build(condition_type: "transaction_type", operator: "=", value: params["transaction_type"])
    end
    rule.actions.build(action_type: "set_transaction_category", value: category.id.to_s)

    unless rule.save
      return error("validation_failed", rule.errors.full_messages.join("; "))
    end

    {
      success: true,
      rule_id: rule.id,
      name: rule.name,
      message: "Created rule \"#{rule.name}\"."
    }
  end

  private
    def error(key, message)
      { success: false, error: key, message: message }
    end
end
