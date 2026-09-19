require "test_helper"

class Api::V1::SavedReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    key = ApiKey.generate_secure_key
    @api_key = ApiKey.create!(user: @user, name: "Reports test", key: key, scopes: [ "draft_write" ], source: "web")
    @read_key = ApiKey.create!(
      user: @user,
      name: "Reports read",
      key: ApiKey.generate_secure_key,
      scopes: [ "read" ],
      source: "web"
    )
  end

  test "lists saved reports" do
    @user.family.saved_reports.create!(user: @user, name: "YTD", config: { "period_type" => "ytd" })

    get api_v1_saved_reports_url, headers: api_headers(@read_key)

    assert_response :success
    names = response.parsed_body.fetch("saved_reports").map { |row| row["name"] }
    assert_includes names, "YTD"
  end

  test "creates a saved report with draft_write" do
    post api_v1_saved_reports_url, params: {
      saved_report: { name: "Custom", config: { period_type: "monthly", sections: [ "net_worth" ] } }
    }, headers: api_headers(@api_key), as: :json

    assert_response :created
    assert_equal "Custom", response.parsed_body.dig("saved_report", "name")
  end

  test "read key cannot create" do
    post api_v1_saved_reports_url, params: {
      saved_report: { name: "Nope", config: { period_type: "monthly" } }
    }, headers: api_headers(@read_key), as: :json

    assert_response :forbidden
  end
end
