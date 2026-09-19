require "test_helper"

class Api::V1::WealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    key = ApiKey.generate_secure_key
    @api_key = ApiKey.create!(user: @user, name: "Wealth test", key: key, scopes: [ "read" ], source: "web")
  end

  test "returns a wealth snapshot" do
    get api_v1_wealth_url, headers: api_headers(@api_key)

    assert_response :success
    assert response.parsed_body["net_worth"].present?
    assert response.parsed_body.key?("allocation")
  end

  test "rejects missing auth" do
    get api_v1_wealth_url

    assert_response :unauthorized
  end

  test "forbids users without preview features" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => false))

    get api_v1_wealth_url, headers: api_headers(@api_key)

    assert_response :forbidden
  end
end
