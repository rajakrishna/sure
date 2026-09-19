class SubscriptionWatchJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      generate_for_family(family_id)
    else
      Family.with_preview_features.find_each do |family|
        SubscriptionWatchJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue subscription watch for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def generate_for_family(family_id)
      family = Family.find_by(id: family_id)
      return unless family&.preview_features_enabled?
      return if family.accounts.none? || family.recurring_transactions_disabled?

      I18n.with_locale(family.locale) do
        Insight::Generators::SubscriptionWatchGenerator.new(family).generate.each do |generated|
          upsert_insight(family, generated)
        end
      end
    rescue => e
      DebugLogEntry.capture(
        category: "subscription_watch",
        level: "error",
        message: "Subscription watch failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end

    def upsert_insight(family, generated)
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
      if existing
        existing.update!(attrs)
      else
        family.insights.create!(attrs)
      end
    end
end
