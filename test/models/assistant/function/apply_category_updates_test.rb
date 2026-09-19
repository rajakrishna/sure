require "test_helper"

class Assistant::Function::ApplyCategoryUpdatesTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::ApplyCategoryUpdates.new(@user)
    @category = categories(:food_and_drink)
  end

  test "to_definition requires updates and is not strict" do
    definition = @fn.to_definition

    assert_equal "apply_category_updates", definition[:name]
    assert_includes definition[:params_schema][:required], "updates"
    refute definition[:strict]
  end

  test "assigns categories by id" do
    entry = create_transaction(account: accounts(:depository), name: "Coffee")

    result = @fn.call("updates" => [
      { "transaction_id" => entry.entryable_id, "category_id" => @category.id }
    ])

    assert result[:success]
    assert_equal 1, result[:applied_count]
    assert_equal @category.id, entry.transaction.reload.category_id
    assert entry.transaction.locked?(:category_id)
  end

  test "assigns categories by name" do
    entry = create_transaction(account: accounts(:depository), name: "Dinner")

    result = @fn.call("updates" => [
      { "transaction_id" => entry.entryable_id, "category_name" => "food & drink" }
    ])

    assert result[:success]
    assert_equal @category.id, entry.transaction.reload.category_id
  end

  test "skips unknown transactions and continues the batch" do
    entry = create_transaction(account: accounts(:depository), name: "Keep going")

    result = @fn.call("updates" => [
      { "transaction_id" => "00000000-0000-0000-0000-000000000000", "category_id" => @category.id },
      { "transaction_id" => entry.entryable_id, "category_id" => @category.id }
    ])

    assert_equal false, result[:success]
    assert_equal 1, result[:applied_count]
    assert_equal 1, result[:skipped_count]
    assert_equal "not_found", result[:skipped].first[:error]
    assert_equal @category.id, entry.transaction.reload.category_id
  end

  test "rejects a category from another family" do
    entry = create_transaction(account: accounts(:depository), name: "Foreign category")
    other_category = Category.create!(
      family: families(:empty),
      name: "Other",
      color: "#e99537",
      lucide_icon: "tag"
    )

    result = @fn.call("updates" => [
      { "transaction_id" => entry.entryable_id, "category_id" => other_category.id }
    ])

    assert_equal false, result[:success]
    assert_equal "invalid_category", result[:skipped].first[:error]
    assert_nil entry.transaction.reload.category_id
  end

  test "does not let a read-only collaborator categorize a shared account" do
    entry = create_transaction(account: accounts(:credit_card), name: "Card charge")
    fn = Assistant::Function::ApplyCategoryUpdates.new(users(:family_member))

    result = fn.call("updates" => [
      { "transaction_id" => entry.entryable_id, "category_id" => @category.id }
    ])

    assert_equal false, result[:success]
    assert_equal "not_authorized", result[:skipped].first[:error]
    assert_nil entry.transaction.reload.category_id
  end

  test "does not categorize another family's transaction" do
    other_family = families(:empty)
    other_account = Account.create!(
      family: other_family,
      name: "Other checking",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )
    entry = create_transaction(account: other_account, name: "Foreign tx")

    result = @fn.call("updates" => [
      { "transaction_id" => entry.entryable_id, "category_id" => @category.id }
    ])

    assert_equal "not_found", result[:skipped].first[:error]
    assert_nil entry.transaction.reload.category_id
  end

  test "rejects more than 100 updates" do
    result = @fn.call("updates" => Array.new(101) { { "transaction_id" => SecureRandom.uuid, "category_id" => @category.id } })

    assert_equal false, result[:success]
    assert_equal "too_many_updates", result[:error]
  end
end
