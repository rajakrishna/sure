require "test_helper"

class AdvisorPortalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @invite = AdvisorInvite.issue!(family: @user.family, created_by: @user, email: "advisor@example.com")
    ensure_tailwind_build
  end

  test "shows a read-only snapshot for a valid invite" do
    get advisor_portal_url(@invite)

    assert_response :success
    assert_match CGI.escapeHTML(I18n.t("advisor_portals.show.read_only")), response.body
    assert @invite.reload.last_viewed_at.present?
  end

  test "does not show a revoked invite" do
    @invite.revoke!

    get advisor_portal_url(@invite)

    assert_response :not_found
  end
end
