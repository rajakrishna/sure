require "test_helper"

class Transactions::InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    ensure_tailwind_build
  end

  test "show renders the review queue" do
    get transactions_inbox_url

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("transactions.inbox.show.title")), response.body
  end

  test "redirects users without preview access" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get transactions_inbox_url

    assert_redirected_to root_path
  end
end
