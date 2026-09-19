class Family::CustomAlertChecker
  def initialize(family)
    @family = family
  end

  def run
    family.custom_alerts.enabled.find_each do |alert|
      next unless triggered?(alert)

      family.insights.create!(
        insight_type: "spending_anomaly",
        title: alert.name,
        body: I18n.t("custom_alerts.kinds.#{alert.kind}"),
        dedup_key: "custom-alert-#{alert.id}-#{Date.current}",
        priority: "medium",
        generated_at: Time.current,
        facts: { "alert_id" => alert.id, "kind" => alert.kind }
      )
      alert.mark_triggered!
    rescue ActiveRecord::RecordInvalid
      next
    end
  end

  private
    attr_reader :family

    def triggered?(alert)
      case alert.kind
      when "upcoming_recurring"
        family.recurring_occurrences.open_status.where(due_on: Date.current..(Date.current + 2)).exists?
      when "overspend"
        snapshot = Family::HomeSnapshot.new(family, user: family.users.first)
        snapshot.budget_chips.any?
      else
        true
      end
    end
end
