class SavedReport < ApplicationRecord
  PERIOD_TYPES = %w[monthly quarterly ytd last_6_months custom].freeze
  SECTION_KEYS = %w[net_worth trends_insights investment_performance investment_flows transactions_breakdown].freeze
  GROUPINGS = %w[category account tag].freeze

  belongs_to :family
  belongs_to :user

  validates :name, presence: true, length: { maximum: 80 }
  validates :config, presence: true
  validate :config_shape

  def period_type
    config["period_type"].presence || "monthly"
  end

  def sections
    Array(config["sections"]).presence || SECTION_KEYS
  end

  def grouping
    config["grouping"].presence || "category"
  end

  def shared_view
    config["shared_view"].presence || "ours"
  end

  def to_filter_params
    {
      period_type: period_type,
      start_date: config["start_date"],
      end_date: config["end_date"],
      filter_category_id: config["filter_category_id"],
      filter_account_id: config["filter_account_id"],
      filter_tag_id: config["filter_tag_id"],
      view: shared_view,
      saved_report_id: id
    }.compact_blank
  end

  private
    def config_shape
      unless PERIOD_TYPES.include?(period_type)
        errors.add(:config, "has an invalid period")
      end

      extra = sections - SECTION_KEYS
      errors.add(:config, "has unknown sections") if extra.any?

      unless GROUPINGS.include?(grouping)
        errors.add(:config, "has an invalid grouping")
      end
    end
end
