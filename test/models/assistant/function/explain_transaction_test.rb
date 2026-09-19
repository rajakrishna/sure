require "test_helper"

class Assistant::Function::ExplainTransactionTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "explains a transaction without writing" do
    user = users(:family_admin)
    account = user.family.accounts.create!(name: "Explain", balance: 10, currency: "USD", accountable: Depository.new)
    entry = create_transaction(account: account, name: "Explain Me")

    result = Assistant::Function::ExplainTransaction.new(user).call("transaction_id" => entry.transaction.id)

    assert result[:success]
    assert_equal "Explain Me", result[:name]
    assert_nil entry.transaction.reload.category
  end
end
