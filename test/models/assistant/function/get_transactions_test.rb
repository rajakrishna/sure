require "test_helper"

class Assistant::Function::GetTransactionsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @transaction = transactions(:one)
    @function = Assistant::Function::GetTransactions.new(@user)
  end

  test "returns transaction ids and notes" do
    @transaction.entry.update!(notes: "Visible note")

    result = @function.call(
      "page" => 1,
      "order" => "asc",
      "search" => @transaction.entry.name
    )

    transaction = result[:transactions].find { |item| item[:id] == @transaction.id }

    assert_not_nil transaction
    assert_equal @transaction.entry.notes, transaction[:notes]
    assert_equal @transaction.entry.date.iso8601, transaction[:date]
    assert_equal Assistant::DateText.format(@transaction.entry.date, family: @user.family), transaction[:date_display]
    assert_match(/\d{4}/, transaction[:date_display])
  end

  test "excludes transactions from inaccessible accounts" do
    hidden_entry = Entry.create!(
      account: accounts(:investment),
      name: "Private investment transaction",
      date: Date.current,
      amount: 100,
      currency: "USD",
      entryable: Transaction.new
    )
    hidden_entry.update!(notes: "Private note")

    result = Assistant::Function::GetTransactions.new(users(:family_member)).call(
      "page" => 1,
      "order" => "asc",
      "search" => hidden_entry.name
    )

    assert_empty result[:transactions]
  end

  test "translates the documented Uncategorized category alias to the filter sentinel" do
    uncategorized_entry = Entry.create!(
      account: accounts(:depository),
      name: "AI uncategorized lookup",
      date: Date.current,
      amount: 42,
      currency: "USD",
      entryable: Transaction.new
    )

    result = @function.call("categories" => [ "Uncategorized" ])
    result_ids = result[:transactions].map { |t| t[:id] }

    assert_includes result_ids, uncategorized_entry.entryable.id
  end

  test "a real category literally named Uncategorized takes priority over the alias translation" do
    family = @user.family
    lookalike_category = family.categories.create!(name: "Uncategorized", color: "#123456")

    lookalike_entry = Entry.create!(
      account: accounts(:depository),
      name: "AI lookalike category lookup",
      date: Date.current,
      amount: 42,
      currency: "USD",
      entryable: Transaction.new(category: lookalike_category)
    )

    truly_uncategorized_entry = Entry.create!(
      account: accounts(:depository),
      name: "AI truly uncategorized lookup",
      date: Date.current,
      amount: 42,
      currency: "USD",
      entryable: Transaction.new
    )

    result = @function.call("categories" => [ "Uncategorized" ])
    result_ids = result[:transactions].map { |t| t[:id] }

    assert_includes result_ids, lookalike_entry.entryable.id
    assert_not_includes result_ids, truly_uncategorized_entry.entryable.id
  end

  test "schema no longer inlines user data enums" do
    schema = @function.params_schema

    %i[accounts categories merchants tags].each do |key|
      items = schema[:properties][key][:items]

      assert_equal({ type: "string" }, items, "#{key} should be a plain string array")
    end
  end

  test "honors page_size" do
    result = @function.call("page_size" => 1)

    assert_equal 1, result[:page_size]
    assert_equal 1, result[:transactions].size
    assert result[:total_pages] > 1
  end

  test "sorts by absolute amount" do
    result = @function.call("sort_by" => "amount", "order" => "desc")

    amounts = result[:transactions].map { |t| t[:amount].abs }

    assert_equal amounts.sort.reverse, amounts
  end

  test "ranking query returns the largest expense first" do
    account = accounts(:depository)
    month = Date.current.strftime("%Y-%m")

    small = Entry.create!(
      account: account,
      name: "Coffee ranking",
      date: Date.current,
      amount: 8,
      currency: "USD",
      entryable: Transaction.new
    )
    large = Entry.create!(
      account: account,
      name: "Rent ranking",
      date: Date.current,
      amount: 2_400,
      currency: "USD",
      entryable: Transaction.new
    )

    result = @function.call(
      "month" => month,
      "sort_by" => "amount",
      "order" => "desc",
      "page_size" => 5,
      "types" => [ "expense" ]
    )

    first = result[:transactions].first
    assert_equal large.entryable.id, first[:id]
    assert_equal 2_400, first[:amount]
    assert_includes result[:transactions].map { |t| t[:id] }, small.entryable.id
  end

  test "filters by type" do
    result = @function.call("types" => [ "income" ])

    assert result[:transactions].any?
    assert result[:transactions].all? { |t| t[:classification] == "income" }
  end

  test "month accepts Month YYYY format" do
    result = @function.call("month" => Date.current.strftime("%B %Y"), "page_size" => 5)

    assert result[:transactions].any?
    assert result[:transactions].all? { |t|
      date = Date.iso8601(t[:date].to_s)
      date.month == Date.current.month && date.year == Date.current.year
    }
  end

  test "month sets a calendar start and end date" do
    result = @function.call("month" => Date.current.strftime("%Y-%m"), "page_size" => 5)

    assert result[:transactions].any?
    assert result[:transactions].all? { |t|
      date = Date.iso8601(t[:date].to_s)
      date.month == Date.current.month && date.year == Date.current.year
    }
  end

  test "invalid month returns an error hint" do
    result = @function.call("month" => "not-a-month")

    assert_equal "invalid_month", result[:error]
    assert_match(/YYYY-MM/, result[:hint])
  end

  test "explicit start and end dates win over month" do
    start_date = 2.days.ago.to_date
    end_date = Date.current

    result = @function.call(
      "month" => "2000-01",
      "start_date" => start_date.iso8601,
      "end_date" => end_date.iso8601
    )

    assert result[:transactions].any?
    assert result[:transactions].all? { |t|
      date = Date.iso8601(t[:date].to_s)
      date >= start_date && date <= end_date
    }
  end

  test "filters by account_ids and ignores inaccessible ids" do
    accessible_account = @transaction.entry.account

    result = @function.call("account_ids" => [ accessible_account.id ])

    assert result[:transactions].any?
    assert result[:transactions].all? { |t| t[:account] == accessible_account.name }

    member_result = Assistant::Function::GetTransactions.new(users(:family_member)).call(
      "account_ids" => [ accounts(:investment).id ]
    )

    assert_empty member_result[:transactions]
  end
end
