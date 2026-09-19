require "application_system_test_case"

class CashFlowTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
  end

  test "home has no sankey chart and keeps the assistant in the right rail" do
    sign_in @user
    visit root_path

    assert_no_selector "#cashflow-preview"
    assert_no_selector "[data-section-key='cashflow_sankey']"
    assert_no_selector "[data-controller='sankey-chart']"
    assert_selector "[data-app-layout-target='rightSidebar']"
    assert_selector "a[data-turbo-frame='sidebar_chat']", minimum: 1
  end
end
