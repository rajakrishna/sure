class Budget::SpendingPlan
  # PocketGuard / Simplifi-style spending plan: income minus bills, goal
  # funding, and spending already posted. Lives beside category envelopes
  # rather than replacing them.
  Line = Data.define(:key, :amount, :href)

  def initialize(budget:, family:, user:, hub:)
    @budget = budget
    @family = family
    @user = user
    @hub = hub
  end

  def income
    return expected_income if expected_income.positive?
    return actual_income if actual_income.positive?

    Money.new(0, currency)
  end

  def bills
    hub.remaining_this_month
  end

  def goals_funding
    @goals_funding ||= begin
      goals = Goal.prepared_for(family, scope: family.goals.where.not(state: Goal::RELEASED_STATES))
      total = goals.reduce(0.to_d) do |sum, goal|
        funded = goal.monthly_budget_funding(budget)
        next sum + funded if funded.positive?

        target = goal.monthly_target_amount
        target.present? ? sum + target.to_d : sum
      end
      Money.new(total, currency)
    end
  end

  def spent
    Money.new(budget.actual_spending, currency)
  end

  def flex
    Money.new(budget.flex_envelope, currency)
  end

  def safe_to_spend
    income - bills - goals_funding - spent
  rescue Money::ConversionError
    Money.new(0, currency)
  end

  def lines
    [
      Line.new(key: "income", amount: income, href: nil),
      Line.new(key: "bills", amount: bills, href: Rails.application.routes.url_helpers.plan_path(tab: "bills")),
      Line.new(key: "goals", amount: goals_funding, href: Rails.application.routes.url_helpers.plan_path(tab: "goals")),
      Line.new(key: "spent", amount: spent, href: Rails.application.routes.url_helpers.budget_path(budget)),
      Line.new(key: "flex", amount: flex, href: nil)
    ]
  end

  private
    attr_reader :budget, :family, :user, :hub

    def currency
      family.currency
    end

    def expected_income
      Money.new(budget.expected_income || 0, currency)
    end

    def actual_income
      Money.new(budget.actual_income || 0, currency)
    end
end
