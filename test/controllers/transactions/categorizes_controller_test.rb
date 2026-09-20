require "test_helper"

class Transactions::CategorizesControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @account = accounts(:depository)
    @category = categories(:food_and_drink)
    # Clear entries for isolation
    @family.accounts.each { |a| a.entries.delete_all }
  end

  # GET /transactions/categorize now lands on Review.

  test "show redirects to the Review inbox" do
    create_transaction(account: @account, name: "Starbucks")
    get transactions_categorize_url
    assert_redirected_to ai_proposals_url
  end

  test "requires authentication" do
    sign_out
    get transactions_categorize_url
    assert_redirected_to new_session_url
  end

  # Account sharing authorization

  test "create does not categorize entries from inaccessible accounts" do
    inaccessible_account = accounts(:investment)     # not shared with family_member
    entry = create_transaction(account: inaccessible_account, name: "Starbucks")

    sign_in users(:family_member)
    post transactions_categorize_url,
      params: {
        position: 0,
        grouping_key: "Starbucks",
        entry_ids: [ entry.id ],
        all_entry_ids: [ entry.id ],
        category_id: @category.id
      },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_nil entry.transaction.reload.category
  end

  test "assign_entry does not categorize an entry from an inaccessible account" do
    inaccessible_account = accounts(:investment)     # not shared with family_member
    entry = create_transaction(account: inaccessible_account, name: "Starbucks")

    sign_in users(:family_member)
    patch assign_entry_transactions_categorize_url, params: {
      entry_id: entry.id,
      category_id: @category.id,
      position: 0,
      all_entry_ids: [ entry.id ]
    }

    assert_response :not_found
    assert_nil entry.transaction.reload.category
  end

  # GET /transactions/categorize/preview_rule

  test "preview_rule returns matching entries for a filter" do
    create_transaction(account: @account, name: "Amazon Prime")
    create_transaction(account: @account, name: "Amazon Music")
    create_transaction(account: @account, name: "Starbucks")

    get preview_rule_transactions_categorize_url(filter: "Amazon"),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "Amazon Prime"
    assert_includes response.body, "Amazon Music"
    assert_not_includes response.body, "Starbucks"
  end

  test "preview_rule returns empty list for blank filter" do
    create_transaction(account: @account, name: "Amazon")

    get preview_rule_transactions_categorize_url(filter: ""),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_not_includes response.body, "Amazon"
  end

  test "preview_rule requires authentication" do
    sign_out
    get preview_rule_transactions_categorize_url(filter: "Amazon")
    assert_redirected_to new_session_url
  end

  private

    def sign_out
      # Deleting sessions through the controller de-authenticates the request the
      # moment our own session dies, so every later delete in the loop is a
      # silent no-op and whichever sessions sort after it survive. The order is
      # unspecified, which made every suite that signs out this way flaky.
      # Teardown hygiene is not the behavior under test, so destroy directly.
      @user.sessions.destroy_all
    end

    # POST /transactions/categorize

    test "create categorizes selected entries and returns redirect stream when all assigned" do
      entry = create_transaction(account: @account, name: "Starbucks")

      post transactions_categorize_url,
        params: {
          position: 0,
          grouping_key: "Starbucks",
          entry_ids: [ entry.id ],
          all_entry_ids: [ entry.id ],
          category_id: @category.id
        },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      assert_response :success
      assert_equal @category, entry.transaction.reload.category
      assert_includes response.body, "action=\"redirect\""
    end

    test "create removes assigned rows and replaces remaining when partial assignment" do
      entry1 = create_transaction(account: @account, name: "Starbucks")
      entry2 = create_transaction(account: @account, name: "Starbucks")

      post transactions_categorize_url,
        params: {
          position: 0,
          grouping_key: "Starbucks",
          entry_ids: [ entry1.id ],
          all_entry_ids: [ entry1.id, entry2.id ],
          category_id: @category.id
        },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      assert_response :success
      assert_equal @category, entry1.transaction.reload.category
      assert_nil entry2.transaction.reload.category
      # Remove stream for categorized entry
      assert_includes response.body, "categorize_entry_#{entry1.id}"
      # Replace stream for remaining entry (re-checked)
      assert_includes response.body, "categorize_entry_#{entry2.id}"
      # No redirect stream — still in the group
      assert_not_includes response.body, "action=\"redirect\""
    end

    test "create with create_rule param creates rule with name and type conditions" do
      entry = create_transaction(account: @account, name: "Netflix", amount: 15)

      assert_difference "@family.rules.count", 1 do
        post transactions_categorize_url,
          params: {
            position: 0,
            grouping_key: "Netflix",
            transaction_type: "expense",
            entry_ids: [ entry.id ],
            all_entry_ids: [ entry.id ],
            category_id: @category.id,
            create_rule: "1"
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      rule = @family.rules.find_by(name: "Netflix")
      assert_not_nil rule
      assert rule.active
      assert rule.conditions.any? { |c| c.condition_type == "transaction_name" && c.value == "Netflix" }
      assert rule.conditions.any? { |c| c.condition_type == "transaction_type" && c.value == "expense" }
    end

    test "create falls back to html redirect without turbo stream header" do
      entry = create_transaction(account: @account, name: "Starbucks")

      post transactions_categorize_url, params: {
        position: 0,
        grouping_key: "Starbucks",
        entry_ids: [ entry.id ],
        all_entry_ids: [ entry.id ],
        category_id: @category.id
      }

      assert_redirected_to transactions_categorize_url(position: 0)
      assert flash[:notice].present?
    end

    # PATCH /transactions/categorize/assign_entry

    test "assign_entry categorizes single entry and returns remove stream" do
      entry = create_transaction(account: @account, name: "Starbucks")
      other = create_transaction(account: @account, name: "Starbucks")

      patch assign_entry_transactions_categorize_url, params: {
        entry_id: entry.id,
        category_id: @category.id,
        position: 0,
        all_entry_ids: [ entry.id, other.id ]
      }

      assert_response :success
      assert_equal @category, entry.transaction.reload.category
      assert_includes response.body, "categorize_entry_#{entry.id}"
      assert_not_includes response.body, "action=\"redirect\""
    end

    test "assign_entry returns redirect stream when last entry in group" do
      entry = create_transaction(account: @account, name: "Starbucks")

      patch assign_entry_transactions_categorize_url, params: {
        entry_id: entry.id,
        category_id: @category.id,
        position: 0,
        all_entry_ids: [ entry.id ]
      }

      assert_response :success
      assert_includes response.body, "action=\"redirect\""
    end
end
