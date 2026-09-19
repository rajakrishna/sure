class Insight::Generators::HouseholdNudgeGenerator < Insight::Generator
  produces "household_nudge"

  def generate
    family.users.where.not(role: "guest").filter_map do |member|
      count = assigned_count(member)
      next if count.zero?

      build_insight(
        insight_type: "household_nudge",
        priority: count >= 5 ? "high" : "medium",
        title: I18n.t("insights.titles.household_nudge", name: member.first_name.presence || member.email, count: count),
        template_key: "household_nudge",
        facts: {
          name: member.first_name.presence || member.email,
          count: count
        },
        metadata: {
          user_id: member.id,
          count_bucket: count >= 5 ? "many" : "few"
        },
        dedup_key: "household_nudge:#{member.id}:#{Date.current.iso8601}"
      )
    end
  end

  private
    def assigned_count(member)
      Transaction::Inbox.uncategorized_for(family).where(assignee_id: member.id).count
    end
end
