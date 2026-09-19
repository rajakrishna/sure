class HouseholdNudgeJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      generate_for_family(family_id)
    else
      Family.with_preview_features.find_each do |family|
        HouseholdNudgeJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue household nudge for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def generate_for_family(family_id)
      family = Family.find_by(id: family_id)
      return unless family&.preview_features_enabled?

      I18n.with_locale(family.locale) do
        Insight::Generators::HouseholdNudgeGenerator.new(family).generate.each do |generated|
          existing = family.insights.find_by(dedup_key: generated.dedup_key)
          attrs = {
            insight_type: generated.insight_type,
            priority: generated.priority,
            status: "active",
            title: generated.title,
            body: Insight::BodyWriter.new(family).write(generated),
            metadata: JSON.parse(generated.metadata.to_json),
            facts: JSON.parse(generated.facts.to_json),
            currency: generated.currency,
            generated_at: Time.current,
            dedup_key: generated.dedup_key
          }
          existing ? existing.update!(attrs) : family.insights.create!(attrs)
        end
      end
    rescue => e
      DebugLogEntry.capture(
        category: "household_nudge",
        level: "error",
        message: "Household nudge failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end
end
