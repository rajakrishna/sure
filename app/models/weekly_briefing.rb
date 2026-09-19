class WeeklyBriefing < ApplicationRecord
  belongs_to :family

  validates :week_of, :payload, :generated_at, presence: true

  scope :recent, -> { order(week_of: :desc, generated_at: :desc) }

  def headline
    payload["headline"]
  end

  def items
    Array(payload["items"])
  end

  def suggested_prompts
    Array(payload["suggested_prompts"])
  end

  def memory_text
    payload["memory"].presence || [ headline, *items.map { |item| item["title"] } ].compact.join(" · ")
  end
end
