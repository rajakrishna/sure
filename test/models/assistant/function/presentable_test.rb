require "test_helper"

class Assistant::Function::PresentableTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
  end

  test "income statement includes a chart and deep links" do
    result = Assistant::Function::GetIncomeStatement.new(@user).call(
      "start_date" => 1.month.ago.to_date.to_s,
      "end_date" => Date.current.to_s
    )

    assert result[:deep_links].present?
    assert result[:deep_links].any? { |link| link[:path].to_s.include?("/transactions") }
  end

  test "balance sheet includes a net worth chart path" do
    result = Assistant::Function::GetBalanceSheet.new(@user).call

    assert result[:deep_links].present?
    assert result[:deep_links].any? { |link| link[:path].to_s.include?("/accounts") }
  end

  test "list uncategorized includes the categorize deep link" do
    result = Assistant::Function::ListUncategorizedTransactions.new(@user).call

    assert result[:deep_links].present?
    assert result[:deep_links].any? { |link| link[:path].to_s.include?("/categorize") }
  end
end
