require "test_helper"

class Settings::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:empty)
    @family = @user.family
  end

  test "redirects to profile when family has no stripe_customer_id" do
    assert_nil @family.stripe_customer_id

    get settings_payment_path
    assert_redirected_to settings_profile_path
  end

  test "redirects to profile when family has stripe_customer_id" do
    @family.update!(stripe_customer_id: "cus_test123")

    get settings_payment_path
    assert_redirected_to settings_profile_path
  end
end
