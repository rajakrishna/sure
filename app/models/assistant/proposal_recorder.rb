class Assistant::ProposalRecorder
  def initialize(chat = nil, user: nil, source: "chat")
    @chat = chat
    @user = user || chat&.user
    @source = source
  end

  def record(function, arguments)
    proposal = AiProposal.record_from_tool!(
      family: user.family,
      user: user,
      chat: chat,
      function: function,
      arguments: arguments,
      source: source
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
    attr_reader :chat, :user, :source
end
