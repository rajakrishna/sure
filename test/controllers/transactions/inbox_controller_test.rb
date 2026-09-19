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

  test "stays available when the preview preference is off" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get transactions_inbox_url

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("transactions.inbox.show.ask_bulk")), response.body
  end

  test "show surfaces pending category suggestions as accept cards" do
    transaction = entries(:transaction).transaction
    category = @user.family.categories.expenses.first
    AiProposal.propose_categorize!(
      family: @user.family,
      transaction: transaction,
      category_id: category.id,
      source: "auto_categorize"
    )

    get transactions_inbox_url

    assert_response :success
    assert_select "#ai-proposals", 1
    assert_match CGI.escapeHTML(I18n.t("ai_proposals.card.approve")), response.body
  end
end
