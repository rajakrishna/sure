class Family::AdaptiveBudgetSuggester
  LOOKBACK_MONTHS = 3

  def initialize(family, user:)
    @family = family
    @user = user
  end

  def propose!
    budget = current_budget
    return [] unless budget

    suggestions = history_averages.filter_map do |category_id, average|
      next if average <= 0

      category = family.categories.find_by(id: category_id)
      next unless category
      next if category.exclude_from_budget?

      {
        "category_id" => category.id,
        "category_name" => category.name,
        "budgeted_spending" => average.round(2)
      }
    end
    return [] if suggestions.empty?

    [ AiProposal.propose_budget_adjust!(
      family: family,
      user: user,
      arguments: { "categories" => suggestions },
      source: "draft_tool",
      target_id: budget.id
    ) ]
  end

  private
    attr_reader :family, :user

    def current_budget
      start_date, end_date = Budget.period_for(Date.current, family: family)
      owner = family.personal_budgets? ? user : nil
      family.budgets.find_by(start_date: start_date, end_date: end_date, user: owner)
    end

    def history_averages
      range = LOOKBACK_MONTHS.months.ago.to_date.beginning_of_month..Date.current.prev_month.end_of_month
      family.transactions
        .joins(:entry, :category)
        .where(categories: { exclude_from_budget: false })
        .where(entries: { date: range, excluded: false })
        .where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)
        .group(:category_id)
        .average("ABS(entries.amount)")
    end
end
