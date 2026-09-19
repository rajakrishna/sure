require "test_helper"

class Family::RefundMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @account = @family.accounts.create!(name: "Refunds", balance: 100, currency: "USD", accountable: Depository.new)
  end

  test "proposes a same-account opposite-amount pair" do
    expense = create_transaction(account: @account, name: "Amazon", amount: 25, date: 3.days.ago.to_date).transaction
    refund = create_transaction(account: @account, name: "Amazon", amount: -25, date: Date.current).transaction

    assert_difference "AiProposal.count", 1 do
      assert_equal 1, Family::RefundMatcher.new(@family).match!
    end

    proposal = @family.ai_proposals.pending.sole
    assert_equal "refund_match", proposal.kind
    assert_equal expense.id, proposal.payload["expense_transaction_id"]
    assert_equal refund.id, proposal.payload["refund_transaction_id"]
  end

  test "does not propose transfers" do
    create_transaction(account: @account, name: "Move", amount: 25, kind: "funds_movement")
    create_transaction(account: @account, name: "Move", amount: -25, kind: "funds_movement")

    assert_equal 0, Family::RefundMatcher.new(@family).match!
  end
end
