require "test_helper"

class PlanHubTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "tab_for defaults unknown tabs to budget" do
    assert_equal "budget", PlanHub.tab_for(nil)
    assert_equal "budget", PlanHub.tab_for("nope")
    assert_equal "goals", PlanHub.tab_for("goals")
    assert_equal "budget", PlanHub.tab_for("budget")
  end

  test "budget_mode_for defaults unknown modes to categories" do
    assert_equal "categories", PlanHub.budget_mode_for(nil)
    assert_equal "categories", PlanHub.budget_mode_for("nope")
    assert_equal "spending_plan", PlanHub.budget_mode_for("spending_plan")
  end

  test "sums visible credit card and loan balances" do
    hub = PlanHub.new(family: @family, user: @user)

    assert_includes hub.debt_accounts.map(&:name), accounts(:credit_card).name
    assert_includes hub.debt_accounts.map(&:name), accounts(:loan).name
    assert_not_includes hub.debt_accounts.map(&:id), accounts(:other_liability).id
    assert_equal Money.new(501_000, @family.currency), hub.debt_total
  end

  test "treats depository balances as cash on hand" do
    hub = PlanHub.new(family: @family, user: @user)

    assert hub.cash_accounts.any? { |account| account.accountable_type == "Depository" }
    assert hub.cash_on_hand.positive?
  end
end
