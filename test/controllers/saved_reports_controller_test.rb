require "test_helper"

class SavedReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
    ensure_tailwind_build
  end

  test "creates a saved report and redirects to reports" do
    assert_difference "SavedReport.count", 1 do
      post saved_reports_url, params: {
        saved_report: {
          name: "Monthly ours",
          config: { period_type: "monthly", shared_view: "ours", sections: [ "net_worth" ] }
        }
      }
    end

    assert_redirected_to reports_path(period_type: "monthly", view: "ours", saved_report_id: SavedReport.last.id)
  end

  test "destroys a saved report" do
    report = @user.family.saved_reports.create!(user: @user, name: "Temp", config: { "period_type" => "monthly" })

    assert_difference "SavedReport.count", -1 do
      delete saved_report_url(report)
    end

    assert_redirected_to reports_path
  end
end
