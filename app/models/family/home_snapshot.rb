class Family::HomeSnapshot
  Chip = Data.define(:name, :percent, :status, :href)
  BillItem = Data.define(:name, :due_on, :amount, :href)

  def initialize(family, user:)
    @family = family
    @user = user
  end

  def safe_to_spend_money
    return paycheck_remaining_money if paycheck_remaining_money

    return nil unless current_budget

    Money.new(current_budget.available_to_spend, family.currency)
  end

  def safe_to_spend_from_paycheck?
    paycheck_remaining_money.present?
  end

  def needs_review_count
    @needs_review_count ||= user.accessible_entries.uncategorized_transactions.count
  end

  def pending_proposal_count
    @pending_proposal_count ||= family.ai_proposals.pending.count
  end

  def budget_pace_percent
    return nil unless current_budget&.initialized?

    current_budget.percent_of_budget_spent
  end

  def budget_days_remaining
    current_budget&.days_remaining
  end

  def budget_chips
    return [] unless current_budget

    current_budget.budget_categories
      .reject(&:subcategory?)
      .select { |bc| bc.over_budget_with_budget? || bc.near_limit? }
      .sort_by { |bc| -(bc.percent_of_budget_spent || 0) }
      .first(4)
      .map do |bc|
        Chip.new(
          name: bc.name,
          percent: (bc.percent_of_budget_spent || 0).round,
          status: bc.over_budget_with_budget? ? "over" : "near",
          href: Rails.application.routes.url_helpers.budget_path(current_budget)
        )
      end
  end

  def upcoming_bills
    return [] unless show_bills?

    occurrences = family.recurring_occurrences
      .open_status
      .joins(:recurring_transaction)
      .where(recurring_transactions: { status: :active })
      .where.not(recurring_transactions: { bill_type: %w[income transfer] })
      .where(due_on: Date.current..(Date.current + 7))
      .includes(recurring_transaction: :merchant)
      .order(:due_on)
      .limit(8)

    occurrences.map do |occurrence|
      series = occurrence.recurring_transaction
      BillItem.new(
        name: series.display_name,
        due_on: occurrence.effective_due_on,
        amount: occurrence.remaining_amount_money,
        href: Rails.application.routes.url_helpers.bill_path(series)
      )
    end
  end

  def weekly_briefing
    @weekly_briefing ||= family.weekly_briefings.recent.first
  end

  def show_bills?
    user.preview_features_enabled? && !family.recurring_transactions_disabled?
  end

  def show_briefing?
    user.preview_features_enabled? && weekly_briefing.present?
  end

  def current_budget
    return @current_budget if defined?(@current_budget)

    budget_start, budget_end = Budget.period_for(Date.current, family: family)
    owner = family.personal_budgets? ? user : nil
    @current_budget = family.budgets.find_by(start_date: budget_start, end_date: budget_end, user: owner)
  end

  private
    attr_reader :family, :user

    def paycheck_remaining_money
      return @paycheck_remaining_money if defined?(@paycheck_remaining_money)

      plan = RecurringTransaction::PaycheckPlanner.new(family, user: user).plan
      period = Array(plan).find { |item| Date.current.between?(item.starts_on, item.ends_on) } || Array(plan).first
      @paycheck_remaining_money = if period
        amount = period.short? ? -period.shortfall : period.remaining
        Money.new(amount, family.currency)
      end
    rescue StandardError
      @paycheck_remaining_money = nil
    end
end
