class Assistant::ProposalRecorder
  def initialize(chat)
    @chat = chat
  end

  def record(function, arguments)
    proposal = AiProposal.record_from_tool!(
      family: chat.user.family,
      user: chat.user,
      chat: chat,
      function: function,
      arguments: arguments
    )

    {
      pending_approval: true,
      proposal_id: proposal.id,
      function_name: function.name,
      summary: proposal.summary,
      message: "This change is waiting for the user to Approve, Edit, or Dismiss. Do not claim it has been applied."
    }
  end

  private
    attr_reader :chat
end
