class PlansController < ApplicationController
  include BudgetOwnership

  # Plan is the GA planning spine (Budget tab). Goals, Bills, Debt and
  # Forecast stay behind the per-user preview toggle — see PlanHub::PREVIEW_TABS.
  # Spending plan, flex, cash-flow calendar, and debt payoff are preview too.
  def show
    @active_tab = PlanHub.tab_for(params[:tab], preview: preview_features_enabled?)
    @budget_mode = PlanHub.budget_mode_for(params[:budget_mode])
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
      @spending_plan = Budget::SpendingPlan.new(
        budget: @budget,
        family: Current.family,
        user: Current.user,
        hub: @plan_hub
      )
      @cash_flow_calendar = CashFlowCalendar.new(
        family: Current.family,
        user: Current.user,
        month: calendar_month
      )
      @debt_planner = Debt::PayoffPlanner.new(
        accounts: @plan_hub.debt_accounts,
        currency: Current.family.currency,
        strategy: params[:strategy],
        extra_payment: params[:extra_payment]
      ).result
    end

    def calendar_month
      Date.strptime(params[:month].to_s, "%Y-%m")
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end
end
