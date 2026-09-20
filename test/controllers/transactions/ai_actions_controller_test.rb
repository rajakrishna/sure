require "test_helper"

class Transactions::AiActionsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "AI action", balance: 80, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "AI Coffee")
    @entry = create_transaction(account: @account, name: "Blue Bottle")
    @entry.transaction.update!(category: @category)
  end

  test "suggest opens a result modal without writing" do
    assert_difference -> { @family.ai_proposals.pending.count }, 1 do
      post transaction_ai_action_url(@entry), params: { kind: "suggest" }
    end

    assert_response :success
    assert_select "[data-testid=ai-proposal-modal]"
    assert_match I18n.t("ai_proposals.card.approve"), response.body
    assert_match I18n.t("ai_proposals.card.dismiss"), response.body
    assert_match I18n.t("ai_proposals.card.edit"), response.body
    assert_equal @category, @entry.transaction.reload.category
  end

  test "split drafts a proposal without writing" do
    assert_difference -> { @family.ai_proposals.pending.where(kind: "split").count }, 1 do
      post transaction_ai_action_url(@entry), params: { kind: "split" }
    end

    assert_response :success
    assert_select "[data-testid=ai-proposal-modal]"
    assert_not @entry.reload.split_parent?
  end

  test "rule drafts a proposal without writing" do
    assert_difference -> { @family.ai_proposals.pending.where(kind: "create_rule").count }, 1 do
      post transaction_ai_action_url(@entry), params: { kind: "rule" }
    end

    assert_response :success
    assert_select "[data-testid=ai-proposal-modal]"
    assert_equal 0, @family.rules.count
  end
end
