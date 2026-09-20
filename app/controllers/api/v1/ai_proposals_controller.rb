# frozen_string_literal: true

class Api::V1::AiProposalsController < Api::V1::BaseController
  before_action :ensure_read_scope, only: :index
  before_action :ensure_draft_write_scope, except: :index
  before_action :set_proposal, only: %i[update approve dismiss]

  def index
    proposals = current_resource_owner.family.ai_proposals.pending.recent.limit(50)

    render json: { ai_proposals: proposals.map { |proposal| serialize(proposal) } }
  end

  def create
    fn_class = Assistant.function_classes(current_resource_owner).find { |klass| klass.name == params[:function_name] }
    unless fn_class
      return render json: { error: "unknown_tool", message: "Unknown tool" }, status: :unprocessable_entity
    end

    fn = fn_class.new(current_resource_owner)
    arguments = proposal_arguments
    result = if fn.mutating?
      Assistant::ProposalRecorder.new(user: current_resource_owner, source: "mcp").record(fn, arguments)
    else
      fn.call(arguments)
    end

    render json: result, status: :created
  end

  def update
    @proposal.update_payload!(proposal_attributes)
    render json: { ai_proposal: serialize(@proposal.reload) }
  end

  def approve
    @proposal.approve!(current_resource_owner, proposal_attributes)
    render json: { ai_proposal: serialize(@proposal.reload) }
  end

  def dismiss
    @proposal.dismiss!(current_resource_owner)
    render json: { ai_proposal: serialize(@proposal.reload) }
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_draft_write_scope
      authorize_scope!(:draft_write)
    end


    def set_proposal
      @proposal = current_resource_owner.family.ai_proposals.pending.find(params[:id])
    end

    def proposal_arguments
      raw = params[:arguments] || params.dig(:ai_proposal, :arguments) || {}
      raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    end

    def proposal_attributes
      raw = params[:ai_proposal] || params.except(:id, :controller, :action, :format)
      raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    end

    def serialize(proposal)
      {
        id: proposal.id,
        kind: proposal.kind,
        source: proposal.source,
        status: proposal.status,
        summary: proposal.summary,
        payload: proposal.payload
      }
    end
end
