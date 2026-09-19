require "test_helper"

class Api::V1::FinancialHealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    key = ApiKey.generate_secure_key
    @api_key = ApiKey.create!(user: @user, name: "Health test", key: key, scopes: [ "read" ], source: "web")
  end

  test "returns a health score" do
    get api_v1_financial_health_url, headers: api_headers(@api_key)

    assert_response :success
    assert_includes 0..100, response.parsed_body.fetch("score")
    assert response.parsed_body["components"].is_a?(Array)
  end

  test "rejects missing auth" do
    get api_v1_financial_health_url

    assert_response :unauthorized
  end
end
