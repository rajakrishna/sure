require "test_helper"

class Family::RuleSuggestFromCorrectionTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @account = @family.accounts.create!(name: "Suggest", balance: 100, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Coffee")
  end

  test "does not propose until the same payee hits the threshold" do
    2.times { create_transaction(account: @account, name: "Starbucks", category: @category) }

    assert_no_difference "AiProposal.count" do
      Family::RuleSuggestFromCorrection.new(@family).record!(@family.transactions.last)
    end
  end

  test "creates a pending create_rule proposal after three matching corrections" do
    3.times { create_transaction(account: @account, name: "Starbucks", category: @category) }

    assert_difference "AiProposal.count", 1 do
      Family::RuleSuggestFromCorrection.new(@family).record!(@family.transactions.last)
    end

    proposal = @family.ai_proposals.pending.sole
    assert_equal "create_rule", proposal.kind
    assert_equal "rule_suggest", proposal.source
    assert_equal "Starbucks", proposal.payload.dig("arguments", "match_value")
    assert_equal @category.id, proposal.payload.dig("arguments", "category_id")
  end

  test "does not duplicate a pending suggestion" do
    3.times { create_transaction(account: @account, name: "Starbucks", category: @category) }
    Family::RuleSuggestFromCorrection.new(@family).record!(@family.transactions.last)

    assert_no_difference "AiProposal.count" do
      Family::RuleSuggestFromCorrection.new(@family).scan_recent
    end
  end
end
