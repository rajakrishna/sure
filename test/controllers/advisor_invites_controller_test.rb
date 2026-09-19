require "test_helper"

class AdvisorInvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    sign_in @user
  end

  test "issues a read-only advisor invite" do
    assert_difference "AdvisorInvite.count", 1 do
      post advisor_invites_url, params: { advisor_invite: { email: "advisor@example.com", name: "Pat" } }
    end

    assert_redirected_to settings_profile_path
    assert_match(/advisor/, flash[:notice])
  end

  test "revokes an invite" do
    invite = AdvisorInvite.issue!(family: @user.family, created_by: @user, email: "advisor@example.com")

    delete advisor_invite_url(invite)

    assert_not_nil invite.reload.revoked_at
  end
end
