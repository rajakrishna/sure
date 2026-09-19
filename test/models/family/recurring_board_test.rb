require "test_helper"

class Family::RecurringBoardTest < ActiveSupport::TestCase
  test "lists this month's active occurrences" do
    family = families(:dylan_family)
    user = users(:family_admin)
    board = Family::RecurringBoard.new(family, user: user, month: Date.current.beginning_of_month)

    assert_kind_of Array, board.items
    assert_equal Date.current.beginning_of_month, board.month
  end
end
