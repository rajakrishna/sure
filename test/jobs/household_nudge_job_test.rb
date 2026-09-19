require "test_helper"

class HouseholdNudgeJobTest < ActiveJob::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
  end

  test "creates a household nudge when assigned uncategorized transactions exist" do
    account = accounts(:depository)
    entry = create_transaction(account: account, name: "Needs review")
    entry.transaction.update!(assignee: @user, category: nil)

    HouseholdNudgeJob.perform_now(family_id: @family.id)

    assert @family.insights.exists?(insight_type: "household_nudge")
  end
end
