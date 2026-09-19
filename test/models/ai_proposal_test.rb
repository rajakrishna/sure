require "test_helper"

class AiProposalTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "Proposal test", balance: 100, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Proposal Coffee")
    @transaction = create_transaction(account: @account, name: "Starbucks").transaction
  end

  test "propose_categorize creates a pending proposal without writing the category" do
    assert_difference "AiProposal.count", 1 do
      assert AiProposal.propose_categorize!(
        family: @family,
        transaction: @transaction,
        category_id: @category.id,
        source: "auto_categorize"
      )
    end

    assert_nil @transaction.reload.category
    proposal = @family.ai_proposals.pending.sole
    assert_equal "categorize", proposal.kind
    assert_equal @category.id, proposal.payload["category_id"]
    assert_equal @transaction.id, proposal.target_id
  end

  test "approve applies the category" do
    AiProposal.propose_categorize!(
      family: @family,
      transaction: @transaction,
      category_id: @category.id,
      source: "bayes"
    )
    proposal = @family.ai_proposals.pending.sole

    proposal.approve!(@user)

    assert_equal "approved", proposal.reload.status
    assert_equal @category, @transaction.reload.category
    assert_equal "bayes", @transaction.data_enrichments.find_by(attribute_name: "category_id").source
  end

  test "dismiss leaves the transaction untouched" do
    AiProposal.propose_categorize!(
      family: @family,
      transaction: @transaction,
      category_id: @category.id,
      source: "auto_categorize"
    )
    proposal = @family.ai_proposals.pending.sole

    proposal.dismiss!(@user)

    assert_equal "dismissed", proposal.reload.status
    assert_nil @transaction.reload.category
  end

  test "approve with create_rule saves a matching rule" do
    AiProposal.propose_categorize!(
      family: @family,
      transaction: @transaction,
      category_id: @category.id,
      source: "auto_categorize"
    )
    proposal = @family.ai_proposals.pending.sole

    assert_difference "Rule.count", 1 do
      proposal.approve!(@user, {}, create_rule: true)
    end

    rule = @family.rules.order(:created_at).last
    assert_equal "Starbucks", rule.name
    assert_equal "transaction_name", rule.conditions.first.condition_type
    assert rule.active
  end

  test "chat mutation is not applied until approved" do
    chat = chats(:one)
    fn = Assistant::Function::CreateTag.new(@user)
    proposal = AiProposal.record_from_tool!(
      family: @family,
      user: @user,
      chat: chat,
      function: fn,
      arguments: { "name" => "Proposal Tag" }
    )

    assert_no_difference "Tag.count" do
      assert proposal.pending?
    end

    assert_difference "Tag.count", 1 do
      proposal.approve!(@user)
    end
    assert_equal "Proposal Tag", @family.tags.find_by(name: "Proposal Tag").name
  end

  test "refund match approval tags both transactions without creating a transfer" do
    expense = create_transaction(account: @account, name: "Amazon", amount: 40).transaction
    refund = create_transaction(account: @account, name: "Amazon", amount: -40).transaction
    proposal = @family.ai_proposals.create!(
      source: "refund_match",
      kind: "refund_match",
      target_type: "Transaction",
      target_id: expense.id,
      payload: {
        "expense_transaction_id" => expense.id,
        "refund_transaction_id" => refund.id,
        "expense_name" => "Amazon",
        "refund_name" => "Amazon"
      }
    )

    assert_no_difference "Transfer.count" do
      proposal.approve!(@user)
    end

    assert_equal "approved", proposal.reload.status
    assert expense.reload.tags.any? { |tag| tag.name == "Refund" }
    assert refund.reload.tags.any? { |tag| tag.name == "Refund" }
  end

  test "merchant proposal does not assign until approved" do
    merchant = ProviderMerchant.create!(name: "Coffee Co", source: "ai")
    AiProposal.propose_merchant!(
      family: @family,
      transaction: @transaction,
      merchant_id: merchant.id,
      merchant_name: merchant.name
    )

    assert_nil @transaction.reload.merchant
    proposal = @family.ai_proposals.pending.sole
    proposal.approve!(@user)
    assert_equal merchant, @transaction.reload.merchant
  end
end
