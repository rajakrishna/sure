class AiProposalsController < ApplicationController
  before_action :set_proposal, only: %i[update approve dismiss restore]

  def index
    @kind = params[:kind].presence
    @source = params[:source].presence
    scope = Current.family.ai_proposals.pending.recent
    scope = scope.where(kind: @kind) if @kind.present?
    scope = scope.where(source: @source) if @source.present?
    @ai_proposals = scope.limit(100)
    @kinds = Current.family.ai_proposals.pending.distinct.pluck(:kind)
    @quality_stats = AiProposal.quality_stats(Current.family)
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.transactions"), transactions_path ],
      [ t("ai_proposals.index.title"), nil ]
    ]
  end

  def update
    @proposal.update_payload!(proposal_params)
    respond_to_card
  end

  def approve
    @proposal.approve!(Current.user, proposal_params, create_rule: params[:create_rule] == "1")
    respond_to_card(notice: t(".success"), location: accept_destination(@proposal))
  end

  def dismiss
    @proposal.dismiss!(Current.user)
    flash[:notice] = {
      "message" => t(".dismissed"),
      "undo_path" => restore_ai_proposal_path(@proposal),
      "undo_label" => t(".undo")
    }
    respond_to_card
  end

  def restore
    @proposal.restore!(Current.user)
    respond_to_card(notice: t(".restored"))
  end

  def bulk_approve
    ids = Array(params[:proposal_ids])
    AiProposal.bulk_approve!(family: Current.family, ids: ids, actor: Current.user)
    redirect_to ai_proposals_path, notice: t(".success", count: ids.size)
  end

  def bulk_dismiss
    ids = Array(params[:proposal_ids])
    AiProposal.bulk_dismiss!(family: Current.family, ids: ids, actor: Current.user)
    redirect_to ai_proposals_path, notice: t(".dismissed", count: ids.size)
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

    def respond_to_card(notice: nil, location: nil)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to(location.presence || ai_proposals_path, notice: notice) }
      end
    end

    def accept_destination(proposal)
      transaction = proposal.target_transaction
      return transaction_path(transaction.entry) if transaction&.entry.present?
      return plan_path(tab: "budget") if proposal.kind == "budget_adjust"

      ai_proposals_path
    end
end
