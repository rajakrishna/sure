require "test_helper"

class Budget::SpendingPlanTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    @budget = budgets(:one)
    @budget.current_user = @user
    @hub = PlanHub.new(family: @family, user: @user)
  end

  test "safe to spend is income minus bills, goal funding, and spending" do
    plan = Budget::SpendingPlan.new(budget: @budget, family: @family, user: @user, hub: @hub)

    expected = plan.income - plan.bills - plan.goals_funding - plan.spent
    assert_equal expected, plan.safe_to_spend
    assert_includes plan.lines.map(&:key), "flex"
  end

  test "falls back to zero income when the budget has none" do
    @budget.update!(expected_income: 0)
    plan = Budget::SpendingPlan.new(budget: @budget, family: @family, user: @user, hub: @hub)

    assert plan.income.amount >= 0
  end
end
