require "test_helper"

class Transactions::ExplainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @entry = entries(:transaction)
  end

  test "explain popover is read-only and auto-runs" do
    get transaction_explain_url(@entry)

    assert_response :success
    assert_select "[data-testid=explain-popover]"
    assert_match I18n.t("transactions.explains.read_only"), response.body
    assert_match I18n.t("transactions.show.open_in_chat"), response.body
    assert_equal @entry.transaction.reload.category_id, @entry.transaction.category_id
  end

  test "cannot explain another family's transaction" do
    other = families(:empty).accounts.create!(
      name: "Other checking",
      balance: 10,
      currency: "USD",
      accountable: Depository.new
    )
    other_entry = other.entries.create!(
      name: "Secret",
      date: Date.current,
      amount: 12,
      currency: "USD",
      entryable: Transaction.new
    )

    get transaction_explain_url(other_entry)
    assert_response :not_found
  end
end
