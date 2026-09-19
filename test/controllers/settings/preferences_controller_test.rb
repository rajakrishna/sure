require "test_helper"

class Settings::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "get" do
    get settings_preferences_url

    assert_response :success
  end

  test "group moniker uses group currencies copy and hides legacy currency field" do
    users(:family_admin).family.update!(moniker: "Group")

    get settings_preferences_url

    assert_response :success
    assert_includes response.body, "Group Currencies"
    assert_includes response.body, "your group"
    assert_select "select[name='user[family_attributes][currency]']", count: 0
  end

  test "does not render a preview features toggle" do
    sign_in users(:family_member)
    get settings_preferences_url

    assert_response :success
    assert_not_includes response.body, "Enable preview features"
  end

  test "update is a no-op redirect" do
    patch settings_preferences_url, params: { user: { preview_features_enabled: "0" } }

    assert_redirected_to settings_preferences_url
    assert users(:family_admin).reload.preview_features_enabled?
  end

  test "household budget toggle and sharing card only render once personal_budgets is on" do
    user = users(:family_admin)
    user.update!(preferences: (user.preferences || {}).merge("preview_features_enabled" => true))

    get settings_preferences_url
    assert_response :success
    assert_not_includes response.body, I18n.t("settings.preferences.show.household_budget_enabled")
    assert_not_includes response.body, I18n.t("settings.preferences.show.budget_sharing_title")

    user.family.update!(personal_budgets: true)

    get settings_preferences_url
    assert_response :success
    assert_includes response.body, I18n.t("settings.preferences.show.household_budget_enabled")
    assert_includes response.body, I18n.t("settings.preferences.show.budget_sharing_title")
  end

  test "intelligence settings render and stay off by default" do
    get settings_preferences_url

    assert_response :success
    assert_includes response.body, I18n.t("settings.preferences.show.intelligence_title")
    assert_includes response.body, I18n.t("settings.preferences.show.high_confidence_auto_apply")
    assert_select "[data-testid=proposal-quality]"
    assert_select "[data-testid=command-palette-trigger]"
    assert_not users(:family_admin).family.high_confidence_auto_apply?
  end

  test "shows the sharing card when personal_budgets is on" do
    user = users(:family_admin)
    user.family.update!(personal_budgets: true)

    get settings_preferences_url

    assert_response :success
    assert_includes response.body, I18n.t("settings.preferences.show.household_budget_enabled")
    assert_includes response.body, I18n.t("settings.preferences.show.budget_sharing_title")
  end
end
