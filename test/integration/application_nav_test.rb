require "test_helper"

class ApplicationNavTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "assistant stays in the mobile bottom nav and the desktop right rail" do
    get root_path
    assert_response :ok

    label = I18n.t("layouts.application.nav.assistant")

    assert_select "nav[aria-label=?] a[href=?]", I18n.t("layouts.application.sidebar_aria"), chats_path, count: 0
    assert_select "#chat-container turbo-frame#sidebar_chat"
    assert_select "#chat-container [data-testid=ds-skeleton]"

    assert_select "nav.fixed.bottom-0 a[href=?]", chats_path do |links|
      assert links.any? { |link| link.text.include?(label) },
        "expected mobile bottom nav to include #{label}"
    end
  end

  test "mobile bottom nav keeps five primary tabs and overflows wealth and reports into More" do
    get root_path
    assert_response :ok

    assert_select "nav.fixed.bottom-0 a[href=?]", root_path
    assert_select "nav.fixed.bottom-0 a[href=?]", transactions_path
    assert_select "nav.fixed.bottom-0 a[href=?]", chats_path
    assert_select "nav.fixed.bottom-0 [data-testid=mobile-more-nav]"
    assert_select "nav.fixed.bottom-0 a[href=?]", wealth_path do |links|
      assert links.any? { |link| link.text.include?(I18n.t("layouts.application.nav.wealth")) }
    end
    assert_select "nav.fixed.bottom-0 a[href=?]", reports_path do |links|
      assert links.any? { |link| link.text.include?(I18n.t("layouts.application.nav.reports")) }
    end
    assert_select "[data-testid=command-palette-trigger-mobile]"
    assert_select "[data-testid=command-palette]"
  end

  test "combined left rail lists workspace destinations with nested plan children" do
    get root_path
    assert_response :ok

    assert_select "nav[aria-label=?]", I18n.t("layouts.application.sidebar_aria") do
      assert_select "p", text: I18n.t("layouts.application.nav.section_workspace")
      assert_select "a[href=?]", root_path
      assert_select "a[href=?]", transactions_path
      assert_select "a[href=?]", plan_path(tab: "budget")
      assert_select "a[href=?]", plan_path(tab: "goals")
      assert_select "a[href=?]", plan_path(tab: "bills")
      assert_select "a[href=?]", wealth_path
      assert_select "a[href=?]", reports_path
    end
  end
end
