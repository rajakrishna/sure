require "test_helper"

class WeeklyBriefingJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "without args fans out to preview families" do
    enable_preview!(@user)

    assert_enqueued_jobs Family.with_preview_features.count, only: WeeklyBriefingJob do
      WeeklyBriefingJob.perform_now
    end
  end

  test "writes a weekly briefing for a preview family" do
    enable_preview!(@user)

    assert_difference "@family.weekly_briefings.count", 1 do
      WeeklyBriefingJob.perform_now(family_id: @family.id)
    end

    briefing = @family.weekly_briefings.recent.first
    assert_equal Date.current.beginning_of_week, briefing.week_of
    assert briefing.headline.present?
  end

  test "writes a briefing even when the preview preference is off" do
    assert_difference "@family.weekly_briefings.count", 1 do
      WeeklyBriefingJob.perform_now(family_id: @family.id)
    end
  end

  private
    def enable_preview!(user)
      user.update!(preferences: (user.preferences || {}).merge("preview_features_enabled" => true))
    end
end
