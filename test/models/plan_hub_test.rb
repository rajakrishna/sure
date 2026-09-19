require "test_helper"

class PlanHubTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "tab_for defaults unknown and gated tabs to budget" do
    assert_equal "budget", PlanHub.tab_for(nil, preview: true)
    assert_equal "budget", PlanHub.tab_for("nope", preview: true)
    assert_equal "goals", PlanHub.tab_for("goals", preview: true)
    assert_equal "budget", PlanHub.tab_for("goals", preview: false)
    assert_equal "budget", PlanHub.tab_for("budget", preview: false)
  end

  test "sums visible credit card and loan balances" do
    hub = PlanHub.new(family: @family, user: @user)

    assert_includes hub.debt_accounts.map(&:name), accounts(:credit_card).name
    assert_includes hub.debt_accounts.map(&:name), accounts(:loan).name
    assert_equal Money.new(501_000, @family.currency), hub.debt_total
  end

  test "treats depository balances as cash on hand" do
    hub = PlanHub.new(family: @family, user: @user)

    assert hub.cash_accounts.any? { |account| account.accountable_type == "Depository" }
    assert hub.cash_on_hand.positive?
  end
end
