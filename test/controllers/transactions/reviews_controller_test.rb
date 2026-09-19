require "test_helper"

class Transactions::ReviewsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "Review inbox", balance: 20, currency: "USD", accountable: Depository.new)
    @entry = create_transaction(account: @account, name: "Unreviewed Coffee")
  end

  test "mark reviewed removes the transaction from the inbox" do
    assert_includes Transaction::Inbox.uncategorized_for(@family), @entry.transaction

    post transactions_review_url, params: { transaction_id: @entry.transaction.id }
    assert_redirected_to transactions_inbox_url
    assert @entry.transaction.reload.reviewed?
    assert_not_includes Transaction::Inbox.uncategorized_for(@family), @entry.transaction
  end
end
