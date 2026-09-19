require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @intro_user = users(:intro_user)
    @family = @user.family
  end

  test "dashboard" do
    get root_path
    assert_response :ok
    assert_match I18n.t("pages.dashboard.home.needs_review"), response.body
    assert_no_match "data-section-key", response.body
    assert_select "#cashflow-preview", count: 0
    assert_select "[data-controller='sankey-chart']", count: 0
    assert_select "#netWorthChart", count: 0
    assert_select "#spending-trend-section", count: 0
  end

  test "dashboard ask chips open the right-rail chat" do
    get root_path

    assert_response :ok
    assert_select "a[data-turbo-frame='sidebar_chat'][data-action='click->app-layout#openRightSidebar']", minimum: 1
  end

  test "inactive user's existing session is revoked" do
    session_record = @user.sessions.order(:created_at).last
    @user.update_column(:active, false)

    get root_path

    assert_redirected_to new_session_path
    assert_not Session.exists?(session_record.id)
  end

  test "update_preferences persists dashboard section layout height" do
    patch "/dashboard/preferences", params: {
      preferences: { dashboard_section_layout: { net_worth_chart: { height: "compact" } } }
    }, as: :json

    assert_response :ok
    assert_equal "compact", @user.reload.dashboard_section_height("net_worth_chart")
  end

  test "update_preferences persists dashboard section width" do
    patch "/dashboard/preferences", params: {
      preferences: { dashboard_section_layout: { cashflow_sankey: { col_span: "single" } } }
    }, as: :json

    assert_response :ok
    assert_equal "single", @user.reload.dashboard_section_width("cashflow_sankey")
  end

  test "update_preferences ignores malformed dashboard_section_layout without erroring" do
    previous_height = @user.reload.dashboard_section_height("net_worth_chart")

    patch "/dashboard/preferences", params: {
      preferences: { dashboard_section_layout: "not-a-hash" }
    }, as: :json

    assert_response :ok
    assert_equal previous_height, @user.reload.dashboard_section_height("net_worth_chart")
  end

  test "dashboard does not build leftover home chart payloads" do
    PagesController.any_instance.expects(:build_cashflow_sankey_data).never
    PagesController.any_instance.expects(:build_spending_trend_data).never
    PagesController.any_instance.expects(:build_money_flow_data).never

    get root_path

    assert_response :ok
  end

  test "intro page requires guest role" do
    get intro_path

    assert_redirected_to root_path
    assert_equal "Intro is only available to guest users.", flash[:alert]
  end

  test "intro page is accessible for guest users" do
    sign_in @intro_user

    get intro_path

    assert_response :ok
  end

  test "dashboard mounts the release highlight when the deployed release is unseen" do
    @user.update!(preferences: {})

    get root_path

    assert_response :ok
    assert_select "[data-controller='release-highlight'][data-release-highlight-tag-value=?]", Sure.version.to_release_tag
  end

  test "dashboard omits the release highlight once the deployed release was seen" do
    @user.mark_release_seen!(Sure.version.to_release_tag)

    get root_path

    assert_response :ok
    assert_select "[data-controller='release-highlight']", count: 0
  end

  test "changelog" do
    VCR.use_cassette("git_repository_provider/fetch_latest_release_notes") do
      get changelog_path
      assert_response :ok
      assert_select "[data-breadcrumbs]", text: /What's new/
    end
  end

  test "changelog with nil release notes" do
    github_provider = mock
    github_provider.expects(:fetch_latest_release_notes).returns(nil)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Release notes unavailable"
    assert_select "a[href='https://github.com/we-promise/sure/releases']"
  end

  test "changelog with incomplete release notes" do
    github_provider = mock
    incomplete_data = {
      avatar: nil,
      username: "maybe-finance",
      name: "Test Release",
      published_at: nil,
      body: nil
    }
    github_provider.expects(:fetch_latest_release_notes).returns(incomplete_data)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Test Release"
  end

  test "feedback" do
    get feedback_path
    assert_response :ok
    assert_select "[data-breadcrumbs]", text: /Feedback/
  end
end
