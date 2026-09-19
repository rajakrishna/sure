class WealthController < ApplicationController
  include SharedViewFilterable

  before_action :require_preview_features!

  def show
    @snapshot = Family::WealthSnapshot.new(
      family: Current.family,
      user: Current.user,
      account_ids: shared_view.ours? ? nil : shared_view.account_ids
    )
    health = Family::FinancialHealth.new(family: Current.family, user: Current.user)
    @health = health.snapshot
    unless Current.family.financial_health_scores.where("generated_at >= ?", Time.current.beginning_of_day).exists?
      health.record!
    end
    @forecast = Current.family.forecast_explains.order(generated_at: :desc).first
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.wealth"), nil ]
    ]
  end
end
