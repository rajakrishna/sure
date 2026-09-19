class PlansController < ApplicationController
  include BudgetOwnership

  # Plan is the GA planning spine (Budget tab). Goals, Bills, Debt and
  # Forecast stay behind the per-user preview toggle — see PlanHub::PREVIEW_TABS.
  def show
    @active_tab = PlanHub.tab_for(params[:tab], preview: preview_features_enabled?)
    @budget = resolve_budget(Date.current)
    @editable = @budget.editable_by?(Current.user)
    @switch_options = budget_switch_options(@budget)
    @top_budget_categories = @budget.initialized? ? @budget.top_spending_categories : []

    if preview_features_enabled?
      load_preview_tabs
    end

    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t("breadcrumbs.plan"), nil ] ]
  end

  private
    def load_preview_tabs
      @goals = Goal.active_prepared_for(Current.family)
      @goals_summary = Goal.summary_for(@goals, currency: Current.family.primary_currency_code)
      # Includes completed/archived goals: the hub is the only route to the
      # goals index for preview users, so the "All goals" link must survive
      # an empty *active* list.
      @family_has_goals = @goals.any? || Current.family.goals.exists?
      @linkable_account_count = Current.user.accessible_accounts
                                       .where(accountable_type: Goal::FUNDABLE_ACCOUNT_TYPES)
                                       .visible
                                       .count
      @plan_hub = PlanHub.new(family: Current.family, user: Current.user)
    end
end
