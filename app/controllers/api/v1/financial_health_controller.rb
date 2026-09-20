# frozen_string_literal: true

class Api::V1::FinancialHealthController < Api::V1::BaseController
  before_action :ensure_read_scope

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
end
