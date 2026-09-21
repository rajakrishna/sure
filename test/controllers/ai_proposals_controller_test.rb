require "test_helper"

class AiProposalsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "Approval test", balance: 50, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Approval Coffee")
    @transaction = create_transaction(account: @account, name: "Blue Bottle").transaction
    AiProposal.propose_categorize!(
      family: @family,
      transaction: @transaction,
      category_id: @category.id,
      source: "auto_categorize",
      user: @user
    )
    @proposal = @family.ai_proposals.pending.sole
  end

  test "approve writes the category" do
    post approve_ai_proposal_url(@proposal)
    assert_redirected_to transaction_path(@transaction.entry)
    assert_equal @category, @transaction.reload.category
    assert_equal "approved", @proposal.reload.status
  end

  test "dismiss does not write the category" do
    post dismiss_ai_proposal_url(@proposal)
    assert_redirected_to ai_proposals_url
    assert_nil @transaction.reload.category
    assert_equal "dismissed", @proposal.reload.status
    assert_equal restore_ai_proposal_path(@proposal), flash[:notice]["undo_path"]
  end

  test "restore returns a dismissed proposal to pending" do
    post dismiss_ai_proposal_url(@proposal)
    post restore_ai_proposal_url(@proposal)

    assert_redirected_to ai_proposals_url
    assert_equal "pending", @proposal.reload.status
    assert_nil @transaction.reload.category
  end

  test "update edits the proposed category" do
    other = @family.categories.create!(name: "Tea")
    patch ai_proposal_url(@proposal), params: { ai_proposal: { category_id: other.id } }
    assert_redirected_to ai_proposals_url
    assert_equal other.id, @proposal.reload.payload["category_id"]
    assert_nil @transaction.reload.category
  end

  test "cannot approve another family's proposal" do
    other_family = families(:empty)
    other_proposal = other_family.ai_proposals.create!(
      source: "chat",
      kind: "mutation",
      function_name: "create_tag",
      payload: { "arguments" => { "name" => "Nope" } }
    )

    post approve_ai_proposal_url(other_proposal)
    assert_response :not_found
  end

  test "index lists pending proposals" do
    get ai_proposals_url
    assert_response :success
    assert_match @proposal.summary, response.body
    assert_select "[data-testid=proposal-quality]"
    assert_match I18n.t("ai_proposals.quality.empty"), response.body
  end

  test "index does not nest per-row accept forms inside the bulk form" do
    get ai_proposals_url
    assert_response :success

    assert_select "form[data-testid=bulk-approve-proposals]", count: 1
    assert_select "form[data-testid=bulk-approve-proposals] form", count: 0
    assert_select "##{dom_id(@proposal)} form[action=?]", approve_ai_proposal_path(@proposal)
    assert_select "[data-testid=proposal-accept]"
    assert_select "input[name='proposal_ids[]'][form=bulk-ai-proposals][value=?]", @proposal.id
  end

  test "bulk approve writes selected proposals" do
    post bulk_approve_ai_proposals_url, params: { proposal_ids: [ @proposal.id ] }
    assert_redirected_to ai_proposals_url
    assert_equal @category, @transaction.reload.category
    assert_equal "approved", @proposal.reload.status
  end

  test "index shows confidence and why" do
    @proposal.update!(payload: @proposal.payload.merge(
      "confidence" => 0.91,
      "reason" => "Learned from coffee",
      "alternatives" => [ { "category_id" => SecureRandom.uuid, "category_name" => "Dining" } ]
    ))

    get ai_proposals_url
    assert_response :success
    assert_match "91%", response.body
    assert_match "Learned from coffee", response.body
    assert_match "Dining", response.body
  end
end
