class ForecastExplain < ApplicationRecord
  belongs_to :family

  validates :horizon_days, numericality: { greater_than: 0 }
  validates :generated_at, presence: true

  scope :recent, -> { order(generated_at: :desc) }

  def remainder_money
    Money.new(projection["remainder"].to_d, family.currency)
  rescue ArgumentError
    Money.new(0, family.currency)
  end
end
