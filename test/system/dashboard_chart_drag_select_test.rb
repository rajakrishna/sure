require "application_system_test_case"

class DashboardChartDragSelectTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
  end

  test "home has no dashboard chart sections to drag" do
    sign_in @user
    visit root_path

    assert_no_selector "[data-section-key]"
    assert_no_selector "#netWorthChart"
  end
end
