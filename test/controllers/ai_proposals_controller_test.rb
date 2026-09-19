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
    assert_redirected_to rules_url
    assert_equal @category, @transaction.reload.category
    assert_equal "approved", @proposal.reload.status
  end

  test "dismiss does not write the category" do
    post dismiss_ai_proposal_url(@proposal)
    assert_redirected_to rules_url
    assert_nil @transaction.reload.category
    assert_equal "dismissed", @proposal.reload.status
  end

  test "update edits the proposed category" do
    other = @family.categories.create!(name: "Tea")
    patch ai_proposal_url(@proposal), params: { ai_proposal: { category_id: other.id } }
    assert_redirected_to rules_url
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

    assert_raises(ActiveRecord::RecordNotFound) do
      post approve_ai_proposal_url(other_proposal)
    end
  end
end
