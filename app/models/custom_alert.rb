class CustomAlert < ApplicationRecord
  KINDS = %w[overspend unusual_amount payday fee_keyword upcoming_recurring].freeze

  belongs_to :family

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }

  def mark_triggered!
    update!(last_triggered_at: Time.current)
  end
end
