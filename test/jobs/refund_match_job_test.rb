require "test_helper"

class RefundMatchJobTest < ActiveJob::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @user = users(:empty)
    @account = @family.accounts.create!(name: "Refund job", balance: 100, currency: "USD", accountable: Depository.new)
  end

  test "creates refund proposals for a preview family" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    create_transaction(account: @account, name: "Store", amount: 18, date: 2.days.ago.to_date)
    create_transaction(account: @account, name: "Store", amount: -18, date: Date.current)

    assert_difference "AiProposal.count", 1 do
      RefundMatchJob.perform_now(family_id: @family.id)
    end

    assert_equal "refund_match", @family.ai_proposals.pending.sole.kind
  end

  test "creates proposals even when the preview preference is off" do
    create_transaction(account: @account, name: "Store", amount: 18)
    create_transaction(account: @account, name: "Store", amount: -18)

    assert_difference "AiProposal.count", 1 do
      RefundMatchJob.perform_now(family_id: @family.id)
    end
  end
end
