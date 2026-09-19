# frozen_string_literal: true

class Api::V1::FinancialHealthController < Api::V1::BaseController
  before_action :ensure_read_scope
  before_action :require_preview_features_for_api

  def show
    snapshot = Family::FinancialHealth.new(
      family: current_resource_owner.family,
      user: current_resource_owner
    ).snapshot

    render json: {
      score: snapshot.score,
      components: snapshot.components_as_json,
      actions: snapshot.actions
    }
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def require_preview_features_for_api
      return if current_resource_owner.preview_features_enabled?

      render_json(
        { error: "feature_disabled", message: "Preview features are not enabled for this user" },
        status: :forbidden
      )
    end
end
