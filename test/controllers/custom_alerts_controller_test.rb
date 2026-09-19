require "test_helper"

class CustomAlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "index and create a custom alert" do
    get custom_alerts_url
    assert_response :success

    assert_difference "CustomAlert.count", 1 do
      post custom_alerts_url, params: { custom_alert: { name: "Overspend food", kind: "overspend", enabled: true } }
    end
    assert_redirected_to custom_alerts_url
  end
end
