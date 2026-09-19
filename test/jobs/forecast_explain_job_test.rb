require "test_helper"

class ForecastExplainJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @family.users.update_all(preferences: { "preview_features_enabled" => true })
  end

  test "stores a deterministic forecast explain" do
    assert_difference "ForecastExplain.count", 1 do
      ForecastExplainJob.perform_now(family_id: @family.id)
    end

    record = @family.forecast_explains.last
    assert record.projection["horizon_days"].present?
    assert record.narration.present?
  end
end
