class AdvisorInvitesController < ApplicationController
  before_action :require_preview_features!
  before_action :require_admin!

  def create
    invite = AdvisorInvite.issue!(
      family: Current.family,
      created_by: Current.user,
      email: params.dig(:advisor_invite, :email),
      name: params.dig(:advisor_invite, :name)
    )
    redirect_to settings_profile_path, notice: t(".created", url: advisor_portal_url(invite.raw_token))
  end

  def destroy
    invite = Current.family.advisor_invites.find(params[:id])
    invite.revoke!
    redirect_to settings_profile_path, notice: t(".revoked")
  end

  private
    def require_admin!
      return if Current.user.admin?

      redirect_to settings_profile_path, alert: t(".not_authorized")
    end
end
