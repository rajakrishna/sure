require "test_helper"

class Api::V1::InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    key = ApiKey.generate_secure_key
    @api_key = ApiKey.create!(user: @user, name: "Inbox test", key: key, scopes: [ "read" ], source: "web")
  end

  test "lists inbox transactions" do
    get api_v1_inbox_url, headers: api_headers(@api_key)

    assert_response :success
    assert response.parsed_body.key?("transactions")
    assert response.parsed_body.key?("assigned_to_me")
  end

  test "rejects missing auth" do
    get api_v1_inbox_url

    assert_response :unauthorized
  end
end
