class AdvisorPortalsController < ApplicationController
  skip_authentication only: :show
  skip_before_action :require_onboarding_and_upgrade, only: :show
  skip_before_action :set_default_chat, only: :show
  layout "auth"

  def show
    @invite = AdvisorInvite.lookup(params[:token])
    raise ActiveRecord::RecordNotFound unless @invite

    @invite.touch_viewed!
    family = @invite.family
    user = family.users.where.not(role: "guest").order(:created_at).first
    @snapshot = Family::WealthSnapshot.new(family: family, user: user)
    snapshot = Family::FinancialHealth.new(family: family, user: user).snapshot
    recorded = family.financial_health_scores.recent.first
    @health_score = recorded&.score || snapshot.score
    @health_components = recorded&.components.presence || snapshot.components_as_json
    @health_actions = recorded&.actions.presence || snapshot.actions
    @period = Period.current_month
    @income_statement = family.income_statement(user: user)
  end
end
