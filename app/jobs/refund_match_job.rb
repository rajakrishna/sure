class RefundMatchJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      run_for_family(family_id)
    else
      Family.find_each do |family|
        RefundMatchJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue refund match for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def run_for_family(family_id)
      family = Family.find_by(id: family_id)
      return if family.accounts.none?

      Family::RefundMatcher.new(family).match!
    rescue => e
      DebugLogEntry.capture(
        category: "refund_match",
        level: "error",
        message: "Refund match failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end
end
