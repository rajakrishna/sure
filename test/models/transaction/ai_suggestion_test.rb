require "test_helper"

class Transaction::AiSuggestionTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @account = @family.accounts.create!(name: "Suggestion", balance: 40, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Suggestion Coffee")
    @entry = create_transaction(account: @account, name: "Cafe Nero")
    @entry.transaction.update!(category: @category)
    @suggestion = Transaction::AiSuggestion.new(
      transaction: @entry.transaction,
      family: @family,
      user: @user
    )
  end

  test "explain is read-only" do
    result = @suggestion.explain

    assert result[:success]
    assert_equal @entry.transaction.id, result[:transaction_id]
    assert Array(result[:deep_links]).any?
    assert_equal @category, @entry.transaction.reload.category
  end

  test "propose categorize creates a pending proposal" do
    proposal = @suggestion.propose!("categorize")

    assert_equal "pending", proposal.status
    assert_equal "categorize", proposal.kind
    assert_equal @category.id, proposal.payload["category_id"]
    assert_equal @category, @entry.transaction.reload.category
  end
end
