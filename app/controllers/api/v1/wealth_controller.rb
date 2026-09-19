# frozen_string_literal: true

class Api::V1::WealthController < Api::V1::BaseController
  before_action :ensure_read_scope
  before_action :require_preview_features_for_api

  def show
    snapshot = Family::WealthSnapshot.new(family: current_resource_owner.family, user: current_resource_owner)

    render json: {
      net_worth: snapshot.net_worth_money.as_json,
      assets: snapshot.assets_money.as_json,
      liabilities: snapshot.liabilities_money.as_json,
      allocation: snapshot.allocation.map { |slice|
        {
          key: slice.key,
          label: slice.label,
          weight: slice.weight,
          classification: slice.classification,
          amount: slice.amount.as_json
        }
      }
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
