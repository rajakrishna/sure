require "test_helper"

class Assistant::Function::EnqueueAutoCategorizeTest < ActiveSupport::TestCase
  include EntriesTestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::EnqueueAutoCategorize.new(@user)
    @family.accounts.each { |account| account.entries.delete_all }
  end

  test "to_definition returns correct name and is not strict" do
    definition = @fn.to_definition

    assert_equal "enqueue_auto_categorize", definition[:name]
    assert_not_empty definition[:description]
    refute definition[:strict]
  end

  test "enqueues auto-categorize jobs in batches" do
    3.times { |i| create_transaction(account: accounts(:depository), name: "Uncat #{i}") }

    result = nil
    assert_enqueued_jobs 2, only: AutoCategorizeJob do
      result = @fn.call("limit" => 3, "batch_size" => 2)
    end

    assert result[:success]
    assert_equal 3, result[:enqueued_count]
    assert_equal 2, result[:batches]
  end

  test "returns zero when nothing is uncategorized" do
    create_transaction(account: accounts(:depository), name: "Done", category: categories(:food_and_drink))

    result = nil
    assert_no_enqueued_jobs only: AutoCategorizeJob do
      result = @fn.call
    end

    assert result[:success]
    assert_equal 0, result[:enqueued_count]
    assert_equal 0, result[:batches]
  end

  test "does not enqueue inaccessible-account transactions" do
    create_transaction(account: accounts(:investment), name: "Private")
    visible = create_transaction(account: accounts(:depository), name: "Shared")
    fn = Assistant::Function::EnqueueAutoCategorize.new(users(:family_member))

    result = nil
    assert_enqueued_jobs 1, only: AutoCategorizeJob do
      result = fn.call
    end

    assert_equal 1, result[:enqueued_count]
    job = enqueued_jobs.find { |item| item[:job] == AutoCategorizeJob }
    serialized_ids = Array(job[:args]).filter_map { |arg|
      arg["transaction_ids"] if arg.is_a?(Hash)
    }.first
    assert_equal [ visible.entryable_id ], serialized_ids
  end

  test "clamps limit and batch_size" do
    create_transaction(account: accounts(:depository), name: "One")

    result = @fn.call("limit" => 5000, "batch_size" => 99)

    assert_equal 1000, result[:limit]
    assert_equal 25, result[:batch_size]
  end
end
