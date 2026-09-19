require "test_helper"

class Family::HomeSnapshotTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @snapshot = Family::HomeSnapshot.new(@family, user: @user)
  end

  test "counts uncategorized transactions as needs review" do
    assert_equal @user.accessible_entries.uncategorized_transactions.count, @snapshot.needs_review_count
  end

  test "hides bills and briefing without preview" do
    assert_not @snapshot.show_bills?
    assert_not @snapshot.show_briefing?
  end

  test "shows a stored briefing when preview is on" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    briefing = @family.weekly_briefings.create!(
      week_of: Date.current.beginning_of_week,
      generated_at: Time.current,
      payload: { "headline" => "Quiet week", "items" => [], "suggested_prompts" => [] }
    )

    snapshot = Family::HomeSnapshot.new(@family.reload, user: @user.reload)
    assert snapshot.show_briefing?
    assert_equal briefing, snapshot.weekly_briefing
  end
end
