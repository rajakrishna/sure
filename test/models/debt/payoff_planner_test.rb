require "test_helper"

class Debt::PayoffPlannerTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @high = create_card("High APR card", balance: 500, apr: 24, minimum: 25)
    @low = create_card("Low APR card", balance: 100, apr: 6, minimum: 20)
  end

  test "avalanche orders by interest rate descending" do
    result = Debt::PayoffPlanner.new(
      accounts: [ @high, @low ],
      currency: "USD",
      strategy: "avalanche"
    ).result

    assert_equal [ @high.id, @low.id ], result.rows.map(&:account_id)
    assert_equal "avalanche", result.strategy
    assert result.months.positive?
    assert result.debt_free_on.present?
  end

  test "snowball orders by balance ascending" do
    result = Debt::PayoffPlanner.new(
      accounts: [ @high, @low ],
      currency: "USD",
      strategy: "snowball"
    ).result

    assert_equal [ @low.id, @high.id ], result.rows.map(&:account_id)
  end

  test "extra payment reduces interest versus minimums only" do
    minimums = Debt::PayoffPlanner.new(
      accounts: [ @high, @low ],
      currency: "USD",
      extra_payment: 0
    ).result
    extra = Debt::PayoffPlanner.new(
      accounts: [ @high, @low ],
      currency: "USD",
      extra_payment: 200
    ).result

    assert extra.months <= minimums.months
    assert extra.total_interest.amount <= minimums.total_interest.amount
    assert extra.interest_saved.amount.positive?
  end

  test "unknown strategy falls back to avalanche and rejects negative extras" do
    assert_equal "avalanche", Debt::PayoffPlanner.strategy_for("nope")
    assert_equal 0, Debt::PayoffPlanner.extra_payment_for(-12)
    assert_equal 0, Debt::PayoffPlanner.extra_payment_for("abc")
  end

  private
    def create_card(name, balance:, apr:, minimum:)
      Account.create!(
        family: @family,
        owner: users(:family_admin),
        name: name,
        balance: balance,
        currency: "USD",
        accountable: CreditCard.new(apr: apr, minimum_payment: minimum),
        status: "active"
      )
    end
end
