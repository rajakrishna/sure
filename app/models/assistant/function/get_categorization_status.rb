class Assistant::Function::GetCategorizationStatus < Assistant::Function
  include Assistant::Function::CategorizeSupport

  class << self
    def name
      "get_categorization_status"
    end

    def description
      <<~INSTRUCTIONS
        Returns how many of the user's accessible transactions are categorized vs
        uncategorized, plus the top category counts.

        Use this before and after batch categorization. Counts follow the same
        rules as the Transactions "Uncategorized" filter (active/draft accounts,
        not excluded, not funds-movement or credit-card payments).
      INSTRUCTIONS
    end
  end

  def call(_params = {})
    uncategorized = uncategorized_entries.count
    categorized = categorized_entries.count

    {
      uncategorized: uncategorized,
      categorized: categorized,
      total: uncategorized + categorized,
      top_categories: top_categories
    }
  end

  private
    def top_categories
      categorized_entries
        .joins("INNER JOIN categories ON categories.id = transactions.category_id")
        .group("categories.id", "categories.name")
        .order(Arel.sql("COUNT(*) DESC"), Arel.sql("categories.name ASC"))
        .limit(TOP_CATEGORY_LIMIT)
        .pluck(Arel.sql("categories.id"), Arel.sql("categories.name"), Arel.sql("COUNT(*)"))
        .map { |id, name, count| { id: id, name: name, count: count } }
    end
end
