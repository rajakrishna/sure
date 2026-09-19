class AiProposalsController < ApplicationController
  before_action :set_proposal

  def update
    @proposal.update_payload!(proposal_params)
    respond_to_card
  end

  def approve
    @proposal.approve!(Current.user, proposal_params, create_rule: params[:create_rule] == "1")
    respond_to_card(notice: t(".success"))
  end

  def dismiss
    @proposal.dismiss!(Current.user)
    respond_to_card(notice: t(".dismissed"))
  end

  private
    def set_proposal
      @proposal = Current.family.ai_proposals.find(params[:id])
    end

    def proposal_params
      params.fetch(:ai_proposal, {}).permit(
        :category_id, :name, :match_value, :transaction_type,
        arguments: {}
      )
    end

    def respond_to_card(notice: nil)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back_or_to rules_path, notice: notice }
      end
    end
end
