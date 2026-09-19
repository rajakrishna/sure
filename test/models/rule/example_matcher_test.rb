require "test_helper"

class Rule::ExampleMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @account = @family.accounts.create!(name: "Matcher test", balance: 1000, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Coffee")
  end

  test "matches a name contains example" do
    rule = create_name_rule("starbucks")
    matcher = Rule::ExampleMatcher.new(rule)

    assert matcher.match?(name: "STARBUCKS Store #12", amount: 6)
    assert_not matcher.match?(name: "Amazon", amount: 6)
  end

  test "matches amount and type together" do
    rule = Rule.create!(
      family: @family,
      resource_type: "transaction",
      conditions: [
        Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: "coffee"),
        Rule::Condition.new(condition_type: "transaction_amount", operator: "<", value: 10)
      ],
      actions: [ Rule::Action.new(action_type: "set_transaction_category", value: @category.id) ]
    )
    matcher = Rule::ExampleMatcher.new(rule)

    assert matcher.match?(name: "Coffee shop", amount: 4)
    assert_not matcher.match?(name: "Coffee shop", amount: 20)
  end

  test "preview lists existing matching transactions" do
    create_transaction(account: @account, name: "Starbucks Downtown")
    create_transaction(account: @account, name: "Whole Foods")
    rule = create_name_rule("starbucks")

    preview = Rule::ExampleMatcher.new(rule).preview

    assert_equal 1, preview[:match_count]
    assert_equal "Starbucks Downtown", preview[:samples].first.name
  end

  private
    def create_name_rule(value)
      Rule.create!(
        family: @family,
        resource_type: "transaction",
        conditions: [ Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: value) ],
        actions: [ Rule::Action.new(action_type: "set_transaction_category", value: @category.id) ]
      )
    end
end
