class Family::WeeklyBriefingBuilder
  def initialize(family)
    @family = family
  end

  def build
    I18n.with_locale(family.locale) do
      items = [
        anomaly_item,
        budget_item,
        new_merchant_item,
        bills_item
      ].compact

      {
        "headline" => headline_for(items),
        "items" => items,
        "suggested_prompts" => prompts_for(items),
        "memory" => memory_for(items)
      }
    end
  end

  private
    attr_reader :family

    def headline_for(items)
      if items.any?
        I18n.t("weekly_briefings.headline.items", count: items.size)
      else
        I18n.t("weekly_briefings.headline.quiet")
      end
    end

    def memory_for(items)
      parts = [ headline_for(items), *items.map { |item| "#{item["title"]}: #{item["body"]}" } ]
      parts.join("\n")
    end

    def prompts_for(items)
      prompts = items.filter_map { |item| item["prompt"] }
      prompts = default_prompts if prompts.empty?
      prompts.first(4)
    end

    def default_prompts
      [
        { "icon" => "wallet", "text" => I18n.t("weekly_briefings.prompts.spending") },
        { "icon" => "chart-area", "text" => I18n.t("weekly_briefings.prompts.budget") },
        { "icon" => "repeat", "text" => I18n.t("weekly_briefings.prompts.bills") }
      ]
    end

    def anomaly_item
      insight = family.insights.visible.where(insight_type: %w[spending_anomaly cash_flow_warning]).ordered.first
      if insight
        return {
          "kind" => "anomaly",
          "title" => insight.title,
          "body" => insight.body.to_s.truncate(160),
          "prompt" => { "icon" => "alert-triangle", "text" => I18n.t("weekly_briefings.prompts.anomaly") }
        }
      end

      current = month_expense_total(Date.current)
      previous = month_expense_total(Date.current << 1)
      return if previous.zero? || current <= previous * BigDecimal("1.15")

      {
        "kind" => "anomaly",
        "title" => I18n.t("weekly_briefings.items.spend_up.title"),
        "body" => I18n.t("weekly_briefings.items.spend_up.body",
          current: Money.new(current, family.currency).format,
          previous: Money.new(previous, family.currency).format),
        "prompt" => { "icon" => "alert-triangle", "text" => I18n.t("weekly_briefings.prompts.anomaly") }
      }
    end

    def budget_item
      budget = current_budget
      return unless budget&.initialized?

      hot = budget.budget_categories.reject(&:subcategory?).select { |bc| bc.over_budget_with_budget? || bc.near_limit? }
      return if hot.empty?

      names = hot.first(3).map(&:name).to_sentence
      {
        "kind" => "budget",
        "title" => I18n.t("weekly_briefings.items.budget.title"),
        "body" => I18n.t("weekly_briefings.items.budget.body", names: names, percent: budget.percent_of_budget_spent.round),
        "prompt" => { "icon" => "chart-area", "text" => I18n.t("weekly_briefings.prompts.budget") }
      }
    end

    def new_merchant_item
      names = new_merchant_names
      return if names.empty?

      {
        "kind" => "merchant",
        "title" => I18n.t("weekly_briefings.items.merchants.title", count: names.size),
        "body" => names.first(4).to_sentence,
        "prompt" => { "icon" => "store", "text" => I18n.t("weekly_briefings.prompts.merchants") }
      }
    end

    def bills_item
      return if family.recurring_transactions_disabled?

      bills = family.recurring_occurrences
        .open_status
        .joins(:recurring_transaction)
        .where(recurring_transactions: { status: :active })
        .where.not(recurring_transactions: { bill_type: %w[income transfer] })
        .where(due_on: Date.current..(Date.current + 7))
        .includes(:recurring_transaction)

      return if bills.empty?

      total = bills.sum { |occurrence| occurrence.remaining_amount }
      {
        "kind" => "bills",
        "title" => I18n.t("weekly_briefings.items.bills.title", count: bills.size),
        "body" => I18n.t("weekly_briefings.items.bills.body",
          amount: Money.new(total, family.currency).format),
        "prompt" => { "icon" => "repeat", "text" => I18n.t("weekly_briefings.prompts.bills") }
      }
    end

    def current_budget
      budget_start, budget_end = Budget.period_for(Date.current, family: family)
      family.budgets.find_by(start_date: budget_start, end_date: budget_end, user: nil)
    end

    def month_expense_total(date)
      start_date, end_date = Budget.period_for(date, family: family)
      period = Period.custom(start_date: start_date, end_date: [ end_date, Date.current ].min)
      family.income_statement.expense_totals(period: period).total
    rescue StandardError
      0
    end

    def new_merchant_names
      recent_ids = family.transactions.joins(:entry)
        .where("entries.date >= ?", 7.days.ago.to_date)
        .where.not(merchant_id: nil)
        .distinct
        .pluck(:merchant_id)

      return [] if recent_ids.empty?

      older_ids = family.transactions.joins(:entry)
        .where("entries.date < ?", 7.days.ago.to_date)
        .where(merchant_id: recent_ids)
        .distinct
        .pluck(:merchant_id)

      Merchant.where(id: recent_ids - older_ids).limit(6).pluck(:name)
    end
end
