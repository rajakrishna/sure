require "test_helper"

class Assistant::Function::ListUncategorizedTransactionsTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::ListUncategorizedTransactions.new(@user)
    @family.accounts.each { |account| account.entries.delete_all }
  end

  test "to_definition returns correct name and is not strict" do
    definition = @fn.to_definition

    assert_equal "list_uncategorized_transactions", definition[:name]
    assert_not_empty definition[:description]
    refute definition[:strict]
  end

  test "lists uncategorized transactions with required fields" do
    entry = create_transaction(
      account: accounts(:depository),
      name: "Starbucks",
      amount: 12.5,
      merchant: merchants(:amazon)
    )

    result = @fn.call
    row = result[:transactions].find { |item| item[:id] == entry.entryable_id }

    assert_not_nil row
    assert_equal entry.date.iso8601, row[:date]
    assert_equal Assistant::DateText.format(entry.date, family: @family), row[:date_display]
    assert_equal "Starbucks", row[:name]
    assert_equal entry.amount.abs, row[:amount]
    assert_equal "expense", row[:classification]
    assert_equal "Amazon", row[:merchant]
    assert_equal accounts(:depository).name, row[:account]
    assert_equal 1, result[:total_results]
  end

  test "omits categorized transactions and funds movement" do
    create_transaction(account: accounts(:depository), name: "Categorized", category: categories(:food_and_drink))
    create_transfer(from_account: accounts(:depository), to_account: accounts(:credit_card), amount: 80)
    visible = create_transaction(account: accounts(:depository), name: "Needs category")

    result = @fn.call

    assert_equal [ visible.entryable_id ], result[:transactions].map { |item| item[:id] }
  end

  test "filters by date range" do
    old_entry = create_transaction(account: accounts(:depository), name: "Old", date: Date.new(2026, 1, 1))
    in_range = create_transaction(account: accounts(:depository), name: "In range", date: Date.new(2026, 8, 15))
    create_transaction(account: accounts(:depository), name: "New", date: Date.new(2026, 9, 1))

    result = @fn.call("start_date" => "2026-08-01", "end_date" => "2026-08-31")

    ids = result[:transactions].map { |item| item[:id] }
    assert_includes ids, in_range.entryable_id
    assert_not_includes ids, old_entry.entryable_id
    assert_equal 1, result[:total_results]
  end

  test "returns invalid_date for a malformed start_date" do
    result = @fn.call("start_date" => "August 2026")

    assert_equal false, result[:success]
    assert_equal "invalid_date", result[:error]
  end

  test "paginates and clamps page_size" do
    5.times { |i| create_transaction(account: accounts(:depository), name: "Uncat #{i}") }

    page1 = @fn.call("page" => 1, "page_size" => 2)
    page2 = @fn.call("page" => 2, "page_size" => 2)

    assert_equal 2, page1[:transactions].size
    assert_equal 2, page1[:page_size]
    assert_equal 5, page1[:total_results]
    assert_not_equal page1[:transactions].map { |item| item[:id] }, page2[:transactions].map { |item| item[:id] }

    clamped = @fn.call("page_size" => 5000)
    assert_equal 100, clamped[:page_size]
  end

  test "hides transactions on inaccessible accounts" do
    create_transaction(account: accounts(:investment), name: "Private")
    visible = create_transaction(account: accounts(:depository), name: "Shared")

    result = Assistant::Function::ListUncategorizedTransactions.new(users(:family_member)).call

    assert_equal [ visible.entryable_id ], result[:transactions].map { |item| item[:id] }
  end
end
