require "test_helper"

class Transactions::InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
    ensure_tailwind_build
  end

  test "show redirects to Review" do
    get transactions_inbox_url

    assert_redirected_to ai_proposals_path
  end
end
