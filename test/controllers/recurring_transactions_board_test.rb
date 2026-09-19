require "test_helper"

class RecurringTransactionsBoardTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "board renders this month's recurrings" do
    get board_recurring_transactions_url
    assert_response :success
    assert_match I18n.t("recurring_transactions.board.title"), response.body
  end
end
