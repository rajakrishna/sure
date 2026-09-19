class CategorizeJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  LOOKBACK_DAYS = 90
  BATCH_LIMIT = 200

  def perform(family_id: nil)
    if family_id.present?
      run_for_family(family_id)
    else
      fan_out
    end
  end

  private
    def fan_out
      Family.with_preview_features.find_each do |family|
        CategorizeJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue categorize job for family #{family.id}: #{e.message}")
      end
    end

    def run_for_family(family_id)
      family = Family.find_by(id: family_id)
      return unless family&.preview_features_enabled?
      return if family.accounts.none?

      ApplyAllRulesJob.perform_now(family, execution_type: "scheduled")
      Family::RuleSuggestFromCorrection.new(family).scan_recent

      ids = uncategorized_ids(family)
      return if ids.empty?

      family.auto_categorize_transactions(ids)
    rescue Family::AutoCategorizer::Error => e
      DebugLogEntry.capture(
        category: "auto_categorization",
        level: "error",
        message: "Nightly categorize skipped LLM: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end

    def uncategorized_ids(family)
      pending_ids = family.ai_proposals.pending.where(kind: "categorize").pluck(:target_id)
      family.entries.uncategorized_transactions
        .where("entries.date >= ?", LOOKBACK_DAYS.days.ago.to_date)
        .order("entries.date DESC")
        .limit(BATCH_LIMIT)
        .pluck("transactions.id")
        .excluding(pending_ids)
    end
end
