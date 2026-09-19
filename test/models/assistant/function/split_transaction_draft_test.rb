require "test_helper"

class Assistant::Function::SplitTransactionDraftTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "proposes a split without writing it" do
    user = users(:family_admin)
    account = accounts(:depository)
    transaction = create_transaction(account: account, name: "Split me", amount: 40).transaction
    fn = Assistant::Function::SplitTransactionDraft.new(user)

    assert_no_difference "Entry.count" do
      result = fn.call(
        "transaction_id" => transaction.id,
        "splits" => [
          { "name" => "A", "amount" => 20 },
          { "name" => "B", "amount" => 20 }
        ]
      )
      assert result[:pending_approval]
    end
  end
end
