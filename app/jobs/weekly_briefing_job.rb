class WeeklyBriefingJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      generate_for_family(family_id)
    else
      Family.with_preview_features.find_each do |family|
        WeeklyBriefingJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue weekly briefing for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def generate_for_family(family_id)
      family = Family.find_by(id: family_id)
      return unless family&.preview_features_enabled?
      return if family.accounts.none?

      week_of = Date.current.beginning_of_week
      payload = Family::WeeklyBriefingBuilder.new(family).build

      briefing = family.weekly_briefings.find_or_initialize_by(week_of: week_of)
      briefing.update!(payload: payload, generated_at: Time.current)
    rescue => e
      DebugLogEntry.capture(
        category: "weekly_briefing",
        level: "error",
        message: "Weekly briefing failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end
end
