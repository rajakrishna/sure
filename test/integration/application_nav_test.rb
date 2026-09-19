require "test_helper"

class ApplicationNavTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "assistant is in both the desktop left nav and the mobile bottom nav" do
    get root_path
    assert_response :ok

    label = I18n.t("layouts.application.nav.assistant")

    assert_select "nav.shrink-0 a[href=?]", chats_path do |links|
      assert links.any? { |link| link.text.include?(label) },
        "expected desktop left nav to include #{label}"
    end

    assert_select "nav.fixed.bottom-0 a[href=?]", chats_path do |links|
      assert links.any? { |link| link.text.include?(label) },
        "expected mobile bottom nav to include #{label}"
    end
  end
end
