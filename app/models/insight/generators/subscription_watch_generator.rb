class Insight::Generators::SubscriptionWatchGenerator < Insight::Generator
  produces "subscription_watch"

  ALERT_DAYS = 7
  MAX_INSIGHTS = 5

  def generate
    return [] if family.recurring_transactions_disabled?

    upcoming.first(MAX_INSIGHTS).map do |recurring|
      name = recurring.display_name
      due_on = recurring.next_expected_date
      days = (due_on - Date.current).to_i
      cancel_url = "https://www.google.com/search?q=#{CGI.escape("how to cancel #{name}")}"

      build_insight(
        insight_type: "subscription_watch",
        priority: days <= 2 ? "high" : "medium",
        title: I18n.t("insights.titles.subscription_watch", name: name),
        template_key: "subscription_watch",
        facts: {
          name: name,
          amount: format_money(recurring.amount),
          due_on: I18n.l(due_on),
          days: days,
          cancel_url: cancel_url
        },
        metadata: {
          recurring_transaction_id: recurring.id,
          due_on: due_on.iso8601,
          days_bucket: days <= 2 ? "soon" : "week"
        },
        dedup_key: "subscription_watch:#{recurring.id}:#{due_on.iso8601}"
      )
    end
  end

  private
    def upcoming
      family.recurring_transactions
        .active
        .where(bill_type: "subscription")
        .where("next_expected_date >= ? AND next_expected_date <= ?", Date.current, Date.current + ALERT_DAYS)
        .includes(:merchant)
        .order(:next_expected_date)
        .to_a
    end
end
