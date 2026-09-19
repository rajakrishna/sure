require "test_helper"

class Assistant::Function::EnqueueDetectMerchantsTest < ActiveSupport::TestCase
  include EntriesTestHelper
  include ActiveJob::TestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::EnqueueDetectMerchants.new(@user)
    @family.accounts.each { |account| account.entries.delete_all }
  end

  test "to_definition returns correct name" do
    definition = @fn.to_definition

    assert_equal "enqueue_detect_merchants", definition[:name]
    refute definition[:strict]
  end

  test "enqueues merchant detection and includes a deep link" do
    2.times { |i| create_transaction(account: accounts(:depository), name: "Shop #{i}") }

    result = nil
    assert_enqueued_jobs 1, only: AutoDetectMerchantsJob do
      result = @fn.call("limit" => 2, "batch_size" => 8)
    end

    assert result[:success]
    assert_equal 2, result[:enqueued_count]
    assert result[:deep_links].present?
  end
end
