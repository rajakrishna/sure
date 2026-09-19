require "test_helper"

class Family::AdaptiveBudgetSuggesterTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "proposes a budget adjust draft from history" do
    user = users(:family_admin)
    family = user.family
    account = family.accounts.create!(name: "Adaptive", balance: 100, currency: "USD", accountable: Depository.new)
    category = family.categories.create!(name: "Adaptive Coffee")
    create_transaction(account: account, name: "Latte", category: category, date: 1.month.ago.to_date, amount: 12)

    assert_difference "AiProposal.where(kind: :budget_adjust).count", 1 do
      Family::AdaptiveBudgetSuggester.new(family, user: user).propose!
    end
  end
end
