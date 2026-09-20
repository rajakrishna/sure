class Assistant::Function::ListUncategorizedTransactions < Assistant::Function
  include Assistant::Function::CategorizeSupport
  include Assistant::Function::Presentable

  class << self
    def default_page_size
      Assistant::Function::CategorizeSupport::DEFAULT_UNCATEGORIZED_PAGE_SIZE
    end

    def name
      "list_uncategorized_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Lists uncategorized transactions for the user to classify. Returns id,
        date, name, amount, classification, merchant, and account.

        Prefer page_size 25-50. Pass optional start_date and end_date (YYYY-MM-DD)
        to limit the window. Then assign categories with apply_category_updates
        using category ids from get_categories.
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
        page: {
          type: "integer",
          minimum: 1,
          description: "Page number (defaults to 1)"
        },
        page_size: {
          type: "integer",
          minimum: 1,
          maximum: MAX_PAGE_SIZE,
          description: "Results per page (defaults to #{self.class.default_page_size})"
        },
        start_date: {
          type: "string",
          description: "Optional YYYY-MM-DD lower bound"
        },
        end_date: {
          type: "string",
          description: "Optional YYYY-MM-DD upper bound"
        }
      }
    )
  end

  def call(params = {})
    start_date, end_date, date_error = resolved_dates(params)
    return date_error if date_error

    scope = uncategorized_entries
    scope = scope.where("entries.date >= ?", start_date) if start_date
    scope = scope.where("entries.date <= ?", end_date) if end_date
    scope = scope.order("entries.date DESC", "entries.id DESC")

    page_size = resolved_page_size(params)
    pagy = Pagy.new(count: scope.count, page: resolved_page(params), limit: page_size)
    entries = scope.preload(:account).offset(pagy.offset).limit(pagy.limit).to_a
    merchants_by_transaction_id = Transaction
      .where(id: entries.map(&:entryable_id))
      .includes(:merchant)
      .index_by(&:id)

    with_presentation(
      {
        transactions: entries.map { |entry| serialize_uncategorized(entry, merchants_by_transaction_id[entry.entryable_id]) },
        total_results: pagy.count,
        page: pagy.page,
        page_size: page_size,
        total_pages: pagy.pages
      },
      deep_links: [ deep_link(I18n.t("assistant.deep_links.categorize"), ai_proposals_path) ]
    )
  end

  private
    def resolved_dates(params)
      start_date = parse_optional_date(params["start_date"], "start_date")
      return [ nil, nil, start_date ] if error_response?(start_date)

      end_date = parse_optional_date(params["end_date"], "end_date")
      return [ nil, nil, end_date ] if error_response?(end_date)

      if start_date && end_date && start_date > end_date
        return [ nil, nil, error("invalid_date_range", "start_date must be on or before end_date.") ]
      end

      [ start_date, end_date, nil ]
    end

    def parse_optional_date(value, field)
      return nil if value.blank?

      parsed = parse_date(value)
      return error("invalid_date", "#{field} must be YYYY-MM-DD.") if parsed.nil?

      parsed
    end

    def error_response?(value)
      value.is_a?(Hash) && value[:success] == false
    end
end
