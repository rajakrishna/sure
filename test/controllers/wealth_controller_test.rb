require "test_helper"

class WealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    ensure_tailwind_build
  end

  test "show renders net worth and health score" do
    get wealth_url

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("wealth.show.title")), response.body
    assert_match CGI.escapeHTML(I18n.t("wealth.show.health_score")), response.body
  end

  test "stays available when the preview preference is off" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get wealth_url

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("wealth.show.ask_idle_cash")), response.body
  end
end
