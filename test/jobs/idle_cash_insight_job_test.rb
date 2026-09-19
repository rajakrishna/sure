require "test_helper"

class IdleCashInsightJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @family.users.update_all(preferences: { "preview_features_enabled" => true })
  end

  test "runs without raising for a preview family" do
    assert_nothing_raised do
      IdleCashInsightJob.perform_now(family_id: @family.id)
    end
  end
end
