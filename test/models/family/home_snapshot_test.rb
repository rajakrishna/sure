require "test_helper"

class Family::HomeSnapshotTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @snapshot = Family::HomeSnapshot.new(@family, user: @user)
  end

  test "counts uncategorized transactions as needs review" do
    expected = @family.entries.joins(:account).merge(Account.accessible_by(@user)).uncategorized_transactions.count
    assert_equal expected, @snapshot.needs_review_count
  end

  test "shows bills when recurring is on and hides briefing until one exists" do
    assert @snapshot.show_bills?
    assert_not @snapshot.show_briefing?
  end

  test "shows a stored briefing when preview is on" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    briefing = @family.weekly_briefings.create!(
      week_of: Date.current.beginning_of_week,
      generated_at: Time.current,
      payload: { "headline" => "Quiet week", "items" => [ { "title" => "Coffee was high" } ], "suggested_prompts" => [] }
    )

    snapshot = Family::HomeSnapshot.new(@family.reload, user: @user.reload)
    assert snapshot.show_briefing?
    assert_equal briefing, snapshot.weekly_briefing
    assert_equal "Coffee was high", snapshot.weekly_briefing.items.first["title"]
  end
end
