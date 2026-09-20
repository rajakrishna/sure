class IdleCashInsightJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform(family_id: nil)
    if family_id.present?
      generate_for_family(family_id)
    else
      Family.find_each do |family|
        IdleCashInsightJob.perform_later(family_id: family.id)
      rescue => e
        Rails.logger.error("Failed to enqueue idle cash insight for family #{family.id}: #{e.message}")
      end
    end
  end

  private
    def generate_for_family(family_id)
      family = Family.find_by(id: family_id)
      return if family.accounts.none?

      user = family.users.with_preview_features.order(:created_at).first
      I18n.with_locale(family.locale) do
        Insight::Generators::IdleCashGenerator.new(family).generate.each do |generated|
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
          propose_budget_move(family, user, generated) if generated.metadata[:goal_id]
        end
      end
    rescue => e
      DebugLogEntry.capture(
        category: "idle_cash",
        level: "error",
        message: "Idle cash insight failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family,
        metadata: { family_id: family_id }
      )
    end

    def propose_budget_move(family, user, generated)
      return unless user
      goal_id = generated.metadata[:goal_id] || generated.metadata["goal_id"]
      return if family.ai_proposals.pending.exists?(kind: "budget_adjust", target_id: goal_id)

      goal = family.goals.find_by(id: goal_id)
      return unless goal&.funding_category_id

      suggested = generated.metadata[:suggested_move] || generated.metadata["suggested_move"]
      AiProposal.propose_budget_adjust!(
        family: family,
        user: user,
        source: "idle_cash",
        target_id: goal.id,
        arguments: {
          "categories" => [
            { "category" => goal.funding_category_id, "amount" => suggested }
          ]
        }
      )
    end
end
