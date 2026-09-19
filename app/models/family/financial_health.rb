class Family::FinancialHealth
  WEIGHTS = {
    emergency_fund: 25,
    savings_rate: 20,
    debt_ratio: 20,
    budget_adherence: 20,
    net_worth_trend: 15
  }.freeze

  Component = Data.define(:key, :score, :weight, :detail)
  Snapshot = Data.define(:score, :components, :actions) do
    def components_as_json
      components.map { |component| { "key" => component.key, "score" => component.score, "weight" => component.weight, "detail" => component.detail } }
    end
  end

  def initialize(family:, user:)
    @family = family
    @user = user
  end

  def snapshot
    parts = [
      emergency_fund_component,
      savings_rate_component,
      debt_ratio_component,
      budget_adherence_component,
      net_worth_trend_component
    ]
    total_weight = parts.sum(&:weight)
    weighted = parts.sum { |part| part.score * part.weight }
    score = total_weight.zero? ? 0 : (weighted / total_weight.to_f).round
    Snapshot.new(score: score.clamp(0, 100), components: parts, actions: actions_for(parts))
  end

  def record!
    FinancialHealthScore.record!(family, snapshot)
  end

  private
    attr_reader :family, :user

    def emergency_fund_component
      expenses = monthly_expenses
      cash = depository_cash
      months = expenses.positive? ? (cash / expenses) : 0
      score = if expenses <= 0
        cash.positive? ? 80 : 40
      else
        ((months / 3.0) * 100).clamp(0, 100).round
      end
      Component.new(
        key: "emergency_fund",
        score: score,
        weight: WEIGHTS[:emergency_fund],
        detail: I18n.t("financial_health.details.emergency_fund", months: months.round(1))
      )
    end

    def savings_rate_component
      income = month_flow(:income)
      expense = month_flow(:expense)
      rate = income.positive? ? ((income - expense) / income) : 0
      score = ((rate / 0.2) * 100).clamp(0, 100).round
      Component.new(
        key: "savings_rate",
        score: score,
        weight: WEIGHTS[:savings_rate],
        detail: I18n.t("financial_health.details.savings_rate", percent: (rate * 100).round)
      )
    end

    def debt_ratio_component
      sheet = family.balance_sheet(user: user)
      assets = sheet.assets.total.to_d
      liabilities = sheet.liabilities.total.to_d
      ratio = assets.positive? ? (liabilities / assets) : (liabilities.positive? ? 1 : 0)
      score = ((1 - ratio) * 100).clamp(0, 100).round
      Component.new(
        key: "debt_ratio",
        score: score,
        weight: WEIGHTS[:debt_ratio],
        detail: I18n.t("financial_health.details.debt_ratio", percent: (ratio * 100).round)
      )
    end

    def budget_adherence_component
      budget = current_budget
      unless budget&.initialized?
        return Component.new(key: "budget_adherence", score: 50, weight: WEIGHTS[:budget_adherence], detail: I18n.t("financial_health.details.budget_missing"))
      end

      spent = budget.percent_of_budget_spent.to_f
      score = if spent <= 100
        100 - [ (100 - spent).abs * 0.15, 20 ].min
      else
        [ 100 - (spent - 100) * 2, 0 ].max
      end
      Component.new(
        key: "budget_adherence",
        score: score.round,
        weight: WEIGHTS[:budget_adherence],
        detail: I18n.t("financial_health.details.budget_adherence", percent: spent.round)
      )
    end

    def net_worth_trend_component
      series = family.balance_sheet(user: user).net_worth_series(period: Period.last_30_days)
      first = series.values.first&.value&.amount.to_d
      last = series.values.last&.value&.amount.to_d
      if first.zero?
        score = last >= 0 ? 60 : 30
      else
        change = (last - first) / first.abs
        score = (50 + change * 200).clamp(0, 100).round
      end
      Component.new(
        key: "net_worth_trend",
        score: score,
        weight: WEIGHTS[:net_worth_trend],
        detail: I18n.t("financial_health.details.net_worth_trend")
      )
    rescue
      Component.new(key: "net_worth_trend", score: 50, weight: WEIGHTS[:net_worth_trend], detail: I18n.t("financial_health.details.net_worth_trend"))
    end

    def actions_for(parts)
      parts.sort_by(&:score).first(3).map do |part|
        { "key" => part.key, "detail" => part.detail, "score" => part.score }
      end
    end

    def current_budget
      @current_budget ||= family.budgets.find_by("start_date <= ? AND end_date >= ? AND user_id IS NULL", Date.current, Date.current)
    end

    def depository_cash
      user.finance_accounts.visible.where(accountable_type: "Depository").sum(:balance).to_d
    end

    def monthly_expenses
      statement = family.income_statement(user: user)
      statement.expense_totals(period: Period.current_month).total.to_d.abs
    rescue
      0
    end

    def month_flow(kind)
      statement = family.income_statement(user: user)
      if kind == :income
        statement.income_totals(period: Period.current_month).total.to_d.abs
      else
        statement.expense_totals(period: Period.current_month).total.to_d.abs
      end
    rescue
      0
    end
end
