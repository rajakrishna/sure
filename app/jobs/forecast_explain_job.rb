class ForecastExplainJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      generate_for_family(family_id)
    else
      Family.find_each do |family|
        ForecastExplainJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue forecast explain for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def generate_for_family(family_id)
      family = Family.find_by(id: family_id)
      return if family.accounts.none?

      user = family.users.order(:created_at).first
      return unless user

      I18n.with_locale(family.locale) do
        Family::ForecastExplainer.new(family: family, user: user).build
      end
    rescue => e
      DebugLogEntry.capture(
        category: "forecast_explain",
        level: "error",
        message: "Forecast explain failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end
end
