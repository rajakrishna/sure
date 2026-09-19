class FinancialHealthScore < ApplicationRecord
  belongs_to :family

  validates :score, presence: true, numericality: { in: 0..100 }
  validates :generated_at, presence: true

  scope :recent, -> { order(generated_at: :desc) }

  def self.record!(family, snapshot)
    family.financial_health_scores.create!(
      score: snapshot.score,
      components: snapshot.components_as_json,
      actions: snapshot.actions,
      generated_at: Time.current
    )
  end
end
