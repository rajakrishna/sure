require "test_helper"

class CategorizeJobTest < ActiveJob::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "without args enqueues one job per preview family" do
    enable_preview!(@user)

    assert_enqueued_jobs Family.with_preview_features.count, only: CategorizeJob do
      CategorizeJob.perform_now
    end
  end

  test "skips families without preview" do
    ApplyAllRulesJob.expects(:perform_now).never

    CategorizeJob.perform_now(family_id: @family.id)
  end

  test "runs rules then auto-categorize remaining ids" do
    enable_preview!(@user)
    ApplyAllRulesJob.expects(:perform_now).with(@family, execution_type: "scheduled").once
    Family::RuleSuggestFromCorrection.any_instance.expects(:scan_recent).once
    Family.any_instance.stubs(:auto_categorize_transactions)

    CategorizeJob.perform_now(family_id: @family.id)
  end

  test "swallows AutoCategorizer errors into a debug log" do
    enable_preview!(@user)
    ApplyAllRulesJob.stubs(:perform_now)
    Family::RuleSuggestFromCorrection.any_instance.stubs(:scan_recent)
    create_transaction(account: accounts(:depository), name: "Needs category")
    Family.any_instance.stubs(:auto_categorize_transactions).raises(Family::AutoCategorizer::Error, "No LLM")

    assert_difference "DebugLogEntry.count", 1 do
      assert_nothing_raised { CategorizeJob.perform_now(family_id: @family.id) }
    end
  end

  private
    def enable_preview!(user)
      user.update!(preferences: (user.preferences || {}).merge("preview_features_enabled" => true))
    end
end
