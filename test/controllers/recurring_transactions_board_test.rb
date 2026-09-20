require "test_helper"

class RecurringTransactionsBoardTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "board redirects to the Plan bills hub" do
    get board_recurring_transactions_url
    assert_redirected_to plan_path(tab: "bills")
  end
end
