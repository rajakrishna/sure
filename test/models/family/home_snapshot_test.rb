require "test_helper"

class Family::HomeSnapshotTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    @family = @user.family
    @snapshot = Family::HomeSnapshot.new(@family, user: @user)
  end

  test "counts uncategorized transactions as needs review" do
    expected = Entry.accessible_uncategorized_count(@user)
    assert_equal expected, @snapshot.needs_review_count
  end

  test "needs_review_count is not inflated by multiple shares on one account" do
    account = accounts(:depository)
    AccountShare.create!(account: account, user: family_guest, permission: "read_only", include_in_finances: true)
    create_transaction(account: account, name: "Share-inflated uncategorized")

    snapshot = Family::HomeSnapshot.new(@family.reload, user: @user.reload)
    canonical = Entry.accessible_uncategorized_count(@user)

    assert_equal canonical, snapshot.needs_review_count
    assert_operator snapshot.needs_review_count, :>=, 1
  end

  test "needs_review_count is zero when every transaction is categorized" do
    category = categories(:food_and_drink)
    @family.entries.uncategorized_transactions.find_each do |entry|
      entry.entryable.update!(category: category)
    end

    snapshot = Family::HomeSnapshot.new(@family.reload, user: @user.reload)
    assert_equal 0, snapshot.needs_review_count
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
