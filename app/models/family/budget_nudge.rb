class Family::BudgetNudge
  Nudge = Data.define(:name, :percent, :days_remaining, :status, :href)

  def initialize(budget)
    @budget = budget
  end

  def items
    return [] unless budget&.initialized?

    days = budget.days_remaining
    budget.budget_categories
      .reject(&:subcategory?)
      .select { |category| category.budgeted? && (category.over_budget_with_budget? || category.near_limit?) }
      .sort_by { |category| -category.percent_of_budget_spent.to_f }
      .first(4)
      .map do |category|
        percent = category.percent_of_budget_spent.to_f.round
        Nudge.new(
          name: category.name,
          percent: percent,
          days_remaining: days,
          status: category.over_budget_with_budget? ? "over" : "near",
          href: Rails.application.routes.url_helpers.budget_budget_category_path(budget, category)
        )
      end
  end

  private
    attr_reader :budget
end
