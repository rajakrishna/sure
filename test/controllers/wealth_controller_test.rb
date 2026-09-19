require "test_helper"

class WealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    ensure_tailwind_build
  end

  test "show renders a single net worth hero" do
    get wealth_url

    assert_response :success
    assert_select "[data-testid=wealth-hero]", 1
    assert_match CGI.escapeHTML(I18n.t("wealth.show.title")), response.body
    assert_match CGI.escapeHTML(I18n.t("wealth.show.health_score")), response.body
    assert_match CGI.escapeHTML(I18n.t("wealth.show.ask_idle_cash")), response.body
    assert_match CGI.escapeHTML(I18n.t("wealth.show.suggest")), response.body
  end

  test "stays available when the preview preference is off" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get wealth_url

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("wealth.show.ask_idle_cash")), response.body
  end

  test "show surfaces pending budget suggestions as accept cards" do
    AiProposal.propose_budget_adjust!(
      family: @user.family,
      user: @user,
      source: "idle_cash",
      arguments: { "budgeted_spending" => 100 }
    )

    get wealth_url

    assert_response :success
    assert_select "#ai-proposals", 1
    assert_match CGI.escapeHTML(I18n.t("ai_proposals.card.approve")), response.body
    assert_match CGI.escapeHTML(I18n.t("ai_proposals.card.dismiss")), response.body
  end

  test "suggest runs idle cash and returns to wealth" do
    assert_nothing_raised do
      post suggest_wealth_url
    end

    assert_redirected_to wealth_path
    assert_equal I18n.t("wealth.show.suggest_done"), flash[:notice]
  end
end
