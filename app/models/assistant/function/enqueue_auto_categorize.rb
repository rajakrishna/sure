class Assistant::Function::EnqueueAutoCategorize < Assistant::Function
  include Assistant::Function::CategorizeSupport
  include Assistant::Function::Presentable

  DEFAULT_LIMIT = 100
  MAX_LIMIT = 1000
  DEFAULT_BATCH_SIZE = 8
  MAX_BATCH_SIZE = 25

  class << self
    def name
      "enqueue_auto_categorize"
    end

    def description
      <<~INSTRUCTIONS
        Enqueues built-in auto-categorize jobs for uncategorized transactions.
        Suggestions wait for Approve / Edit / Dismiss — this does not apply categories itself.
        Prefer apply_category_updates when an agent can classify the rows itself,
        especially on a slow local GPU.

        Optional limit (default #{DEFAULT_LIMIT}, max #{MAX_LIMIT}) and batch_size
        (default #{DEFAULT_BATCH_SIZE}, max #{MAX_BATCH_SIZE}).
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        limit: {
          type: "integer",
          minimum: 1,
          maximum: MAX_LIMIT,
          description: "Max transactions to enqueue (defaults to #{DEFAULT_LIMIT})"
        },
        batch_size: {
          type: "integer",
          minimum: 1,
          maximum: MAX_BATCH_SIZE,
          description: "Per-job batch size (defaults to #{DEFAULT_BATCH_SIZE})"
        }
      }
    )
  end

  def call(params = {})
    limit = integer_param(params["limit"], DEFAULT_LIMIT).clamp(1, MAX_LIMIT)
    batch_size = integer_param(params["batch_size"], DEFAULT_BATCH_SIZE).clamp(1, MAX_BATCH_SIZE)

    transaction_ids = uncategorized_entries
      .order("entries.date DESC", "entries.id DESC")
      .limit(limit)
      .pluck("transactions.id")

    if transaction_ids.empty?
      return {
        success: true,
        enqueued_count: 0,
        batches: 0,
        message: "No uncategorized transactions to enqueue."
      }
    end

    batches = 0
    transaction_ids.each_slice(batch_size) do |ids|
      family.auto_categorize_transactions_later(family.transactions.where(id: ids))
      batches += 1
    end

    with_presentation(
      {
        success: true,
        enqueued_count: transaction_ids.size,
        batches: batches,
        limit: limit,
        batch_size: batch_size,
        message: "Enqueued #{transaction_ids.size} transactions for categorization. Suggestions will wait for approval."
      },
      deep_links: [ deep_link(I18n.t("assistant.deep_links.categorize"), ai_proposals_path) ]
    )
  end

  private
    def integer_param(value, default)
      return default if value.blank?

      value.to_i
    end
end
