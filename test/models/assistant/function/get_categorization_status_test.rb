require "test_helper"

class Assistant::Function::GetCategorizationStatusTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetCategorizationStatus.new(@user)
    @family.accounts.each { |account| account.entries.delete_all }
  end

  test "to_definition returns correct name" do
    definition = @fn.to_definition

    assert_equal "get_categorization_status", definition[:name]
    assert_not_empty definition[:description]
    assert definition[:strict]
  end

  test "counts categorized and uncategorized transactions" do
    create_transaction(account: accounts(:depository), name: "Coffee", category: categories(:food_and_drink))
    create_transaction(account: accounts(:depository), name: "Unknown")
    create_transaction(account: accounts(:depository), name: "Also unknown")

    result = @fn.call

    assert_equal 1, result[:categorized]
    assert_equal 2, result[:uncategorized]
    assert_equal 3, result[:total]
    assert_equal categories(:food_and_drink).id, result[:top_categories].first[:id]
    assert_equal 1, result[:top_categories].first[:count]
  end

  test "excludes funds movement transfers from both counts" do
    create_transfer(from_account: accounts(:depository), to_account: accounts(:credit_card), amount: 50)
    create_transaction(account: accounts(:depository), name: "Groceries")

    result = @fn.call

    assert_equal 0, result[:categorized]
    assert_equal 1, result[:uncategorized]
    assert_equal 1, result[:total]
  end

  test "does not count transactions on inaccessible accounts" do
    create_transaction(account: accounts(:investment), name: "Private uncategorized")
    create_transaction(account: accounts(:depository), name: "Visible uncategorized")

    result = Assistant::Function::GetCategorizationStatus.new(users(:family_member)).call

    assert_equal 1, result[:uncategorized]
    assert_equal 1, result[:total]
  end

  test "does not count another family's transactions" do
    other_family = families(:empty)
    other_account = Account.create!(
      family: other_family,
      name: "Other checking",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )
    create_transaction(account: other_account, name: "Foreign")

    result = @fn.call

    assert_equal 0, result[:uncategorized]
    assert_equal 0, result[:categorized]
  end
end
