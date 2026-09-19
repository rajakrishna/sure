require "test_helper"

class PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    ensure_tailwind_build
  end


  # The status pill beside this bar was already amber for a depleted reserve
  # while the bar itself stayed neutral: the same goal reported as needing
  # attention and not, an inch apart.
  #
  # Counted rather than matched: a fixture goal is already off its pace, so
  # the markup is on the page either way and a presence check passes without
  # the fix.
  test "the goals card bars a depleted reserve in warning colour" do
    bar = /h-full bg-warning rounded-full/

    get plan_url
    before = response.body.scan(bar).size

    family = @user.family
    account = Account.create!(family: family, accountable: Depository.new,
                              name: "Reserve pot", currency: family.currency, balance: 1_000)
    family.goals.create!(name: "Precaution", target_amount: 6_000,
                         currency: family.currency, kind: "maintained") do |g|
      g.goal_accounts.build(account: account, allocated_amount: 1_000)
    end

    get plan_url

    assert_response :success
    assert_equal before + 1, response.body.scan(bar).size,
                 "the depleted reserve's bar stayed neutral"
  end

  test "renders every plan tab without a preview preference" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get plan_url

    assert_response :success
    assert_match I18n.t("plans.budget_card.title"), response.body
    assert_select "[data-testid=?]", "plan-hub-tabs"
    assert_match I18n.t("plans.show.tabs.goals"), response.body
    assert_no_match I18n.t("plans.show.preview_nudge.title"), response.body
  end

  test "renders all plan tabs for preview users" do
    get plan_url

    assert_response :success
    assert_select "[data-testid=?]", "plan-hub-tabs"
    assert_match I18n.t("plans.show.tabs.budget"), response.body
    assert_match I18n.t("plans.show.tabs.goals"), response.body
    assert_match I18n.t("plans.show.tabs.bills"), response.body
    assert_match I18n.t("plans.show.tabs.debt"), response.body
    assert_match I18n.t("plans.show.tabs.forecast"), response.body
  end

  test "nests plan children in the left rail and keeps assistant out of it" do
    get plan_url

    assert_response :success
    assert_select "nav[aria-label=?]", I18n.t("layouts.application.sidebar_aria") do
      assert_select "a[href=?]", plan_path(tab: "bills")
      assert_select "a[href=?]", plan_path(tab: "budget")
      assert_select "a[href=?]", chats_path, count: 0
    end
    assert_select "#chat-container turbo-frame#sidebar_chat"
  end

  test "opens a requested plan tab even without a preview preference" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get plan_url(tab: "goals")

    assert_response :success
    assert_select "[data-testid=?]", "plan-hub-tabs"
    assert_match I18n.t("plans.goals_card.title"), response.body
  end

  test "renders budget and goals summary cards with drill-in links" do
    get plan_url

    assert_response :success
    assert_match I18n.t("plans.budget_card.title"), response.body
    assert_match I18n.t("plans.goals_card.title"), response.body
    assert_select "a[href=?]", budget_path(Budget.date_to_param(Date.current))
    assert_select "a[href=?]", goals_path
  end

  test "lists active goals with links to their detail pages" do
    get plan_url

    assert_response :success
    goal = goals(:vacation_italy)
    assert_match goal.name, response.body
    assert_select "a[href=?]", goal_path(goal)
  end

  test "shows the goals empty state when the family has no goals" do
    @user.family.goals.destroy_all

    get plan_url

    assert_response :success
    assert_match I18n.t("goals.empty_state.body"), response.body
    assert_select "a[href=?]", goals_path, count: 0
  end

  test "keeps the all-goals link when only completed or archived goals remain" do
    @user.family.goals.each { |goal| goal.update_columns(state: "archived") }

    get plan_url

    assert_response :success
    assert_match I18n.t("goals.empty_state.body"), response.body
    assert_select "a[href=?]", goals_path, minimum: 1
  end

  test "shows the budget setup CTA when the month is uninitialized" do
    budgets(:one).update!(budgeted_spending: nil)

    get plan_url

    assert_response :success
    assert_match I18n.t("plans.budget_card.empty_body"), response.body
    assert_select "a[href=?]", edit_budget_path(Budget.date_to_param(Date.current))
  end

  test "lists credit card and loan accounts on the debt tab" do
    get plan_url(tab: "debt")

    assert_response :success
    assert_select "[data-testid=?] [role=tabpanel][data-id=?]", "plan-hub-tabs", "debt" do
      assert_select "a[href=?]", account_path(accounts(:credit_card))
      assert_select "a[href=?]", account_path(accounts(:loan))
      assert_select "a[href=?]", account_path(accounts(:other_liability)), count: 0
    end
  end

  test "links the bills card through to the bills workspace" do
    get plan_url(tab: "bills")

    assert_response :success
    assert_select "[data-testid=?] [role=tabpanel][data-id=?]", "plan-hub-tabs", "bills" do
      assert_select "h2", text: I18n.t("plans.bills_card.title")
      assert_select "a[href=?]", bills_path
    end
  end

  test "spending plan mode renders safe-to-spend beside categories" do
    get plan_url(tab: "budget", budget_mode: "spending_plan")

    assert_response :success
    assert_select "[data-testid=?]", "spending-plan"
    assert_match I18n.t("plans.spending_plan.safe_to_spend"), response.body
    assert_match I18n.t("plans.budget_card.mode_categories"), response.body
  end

  test "category mode shows the flex envelope for preview users" do
    get plan_url(tab: "budget")

    assert_response :success
    assert_select "[data-testid=?]", "flex-envelope"
    assert_select "[data-testid=?]", "spending-plan", count: 0
  end

  test "forecast tab renders the day-level cash-flow calendar" do
    get plan_url(tab: "forecast")

    assert_response :success
    assert_select "[data-testid=?]", "cash-flow-calendar"
  end

  test "debt tab renders avalanche/snowball what-if planner" do
    get plan_url(tab: "debt", strategy: "snowball", extra_payment: 50)

    assert_response :success
    assert_select "[data-testid=?]", "debt-payoff-planner"
    assert_match I18n.t("plans.debt_planner.snowball"), response.body
  end

  test "goals tab shows budget category funding when linked" do
    goal = goals(:vacation_italy)
    goal.update!(funding_category: categories(:food_and_drink))

    get plan_url(tab: "goals")

    assert_response :success
    assert_match ERB::Util.html_escape(I18n.t("plans.goals_card.funded_from", category: categories(:food_and_drink).name)), response.body
  end
end

class PlansControllerHouseholdSwitchingTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:empty)
    @family.update!(personal_budgets: true)
    @owner = users(:josh)
    @owner.update!(preferences: (@owner.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @owner
    ensure_tailwind_build
  end

  test "renders a household/mine switcher once personal_budgets is on, and switches to household" do
    get plan_url

    assert_response :success
    assert_select "a[href=?]", plan_path(owner: "household")
    assert_select "a[href=?]", plan_path(owner: @owner.id)

    get plan_url, params: { owner: "household" }
    assert_response :success
  end

  test "hides the household pill when household_budget_enabled is off" do
    @family.update!(household_budget_enabled: false)

    get plan_url

    assert_response :success
    assert_select "a[href=?]", plan_path(owner: "household"), count: 0
  end
end
