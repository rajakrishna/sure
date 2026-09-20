class WealthController < ApplicationController
  include SharedViewFilterable

  def show
    load_snapshot
    @ai_proposals = Current.family.ai_proposals.pending.where(kind: %w[budget_adjust]).recent
    @sparkline_series = @snapshot.sparkline_series
    @net_worth_estimate = Family::NetWorthEstimate.new(Current.family, user: Current.user).intra_period
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.wealth"), nil ]
    ]
  end

  def suggest
    IdleCashInsightJob.perform_now(family_id: Current.family.id)
    redirect_to wealth_path, notice: t("wealth.show.suggest_done")
  end

  private
    def load_snapshot
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
    end
end
