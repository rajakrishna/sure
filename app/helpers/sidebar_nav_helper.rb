module SidebarNavHelper
  def app_sidebar_plan_open?
    page_active?(plan_path) || page_active?(budgets_path) ||
      page_active?(goals_path) || page_active?(bills_path)
  end

  def app_sidebar_plan_children
    [
      { name: t("layouts.application.nav.budgets"), path: plan_path(tab: "budget"), active: plan_tab_active?("budget") },
      { name: t("layouts.application.nav.goals"), path: plan_path(tab: "goals"), active: plan_tab_active?("goals") || page_active?(goals_path) },
      { name: t("layouts.application.nav.bills"), path: plan_path(tab: "bills"), active: plan_tab_active?("bills") || page_active?(bills_path) },
      { name: t("layouts.application.nav.debt"), path: plan_path(tab: "debt"), active: plan_tab_active?("debt") },
      { name: t("layouts.application.nav.forecast"), path: plan_path(tab: "forecast"), active: plan_tab_active?("forecast") }
    ]
  end

  def app_sidebar_primary_items
    [
      { name: t("layouts.application.nav.home"), path: root_path, icon: "home", active: page_active?(root_path) },
      { name: t("layouts.application.nav.transactions"), path: transactions_path, icon: "credit-card", active: page_active?(transactions_path) },
      {
        name: t("layouts.application.nav.plan"),
        path: plan_path,
        icon: "compass",
        active: app_sidebar_plan_open?,
        children: app_sidebar_plan_children
      },
      { name: t("layouts.application.nav.wealth"), path: wealth_path, icon: "wallet", active: page_active?(wealth_path) },
      { name: t("layouts.application.nav.reports"), path: reports_path, icon: "chart-bar", active: page_active?(reports_path) }
    ]
  end

  private
    def plan_tab_active?(tab)
      return false unless request.path == plan_path

      (params[:tab].presence || "budget").to_s == tab
    end
end