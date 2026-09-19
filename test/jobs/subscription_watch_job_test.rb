require "test_helper"

class SubscriptionWatchJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @family.users.update_all(preferences: { "preview_features_enabled" => true })
  end

  test "creates a subscription watch insight for due subscriptions" do
    recurring = recurring_transactions(:netflix_subscription)
    recurring.update!(bill_type: "subscription", next_expected_date: 3.days.from_now.to_date)

    assert_difference -> { @family.insights.where(insight_type: "subscription_watch").count }, 1 do
      SubscriptionWatchJob.perform_now(family_id: @family.id)
    end
  end
end
