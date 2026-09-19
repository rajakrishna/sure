require "test_helper"

class CashFlowCalendarTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    @account = accounts(:depository)
    @family.recurring_transactions.destroy_all
  end

  test "places income and bills on the due day and nets the month" do
    due = Date.current
    create_series(name: "Paycheck", amount: -2000, due: due, income: true)
    create_series(name: "Rent", amount: 1500, due: due)

    calendar = CashFlowCalendar.new(family: @family, user: @user, month: due)

    day = calendar.days.find { |entry| entry.date == due }
    assert_equal 2, day.events.size
    assert_equal 2000, day.inflow.amount
    assert_equal 1500, day.outflow.amount
    assert_equal 500, day.net.amount
    assert_not_nil day.running_balance
    assert_equal day.net, calendar.month_net
    past = calendar.days.find { |entry| entry.in_month && entry.date < Date.current }
    assert_nil past.running_balance if past
  end

  test "skips transfer series" do
    due = Date.current
    @family.recurring_transactions.create!(
      name: "To savings",
      account: @account,
      amount: 100,
      currency: "USD",
      bill_type: "transfer",
      expected_day_of_month: due.day,
      anchor_date: due,
      last_occurrence_date: due,
      next_expected_date: due,
      status: "active",
      manual: true
    )

    calendar = CashFlowCalendar.new(family: @family, user: @user, month: due)
    day = calendar.days.find { |entry| entry.date == due }

    assert day.events.empty?
  end

  private
    def create_series(name:, amount:, due:, income: false)
      @family.recurring_transactions.create!(
        name: name,
        account: @account,
        amount: amount,
        currency: "USD",
        bill_type: income ? "income" : "bill",
        expected_day_of_month: due.day,
        anchor_date: due,
        last_occurrence_date: due,
        next_expected_date: due,
        status: "active",
        manual: true
      )
    end
end
