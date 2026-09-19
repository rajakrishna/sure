class Assistant::Function::ProposeBudgetAdjust < Assistant::Function
  class << self
    def name
      "propose_budget_adjust"
    end

    def description
      <<~INSTRUCTIONS
        Drafts a budget amount change for human approval. Never updates the
        budget until the user Approves. Same arguments as update_budget.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    Assistant::Function::UpdateBudget.new(user).params_schema
  end

  def call(params = {})
    unless params.key?("budgeted_spending") || params.key?("expected_income") || Array(params["categories"]).any?
      return { success: false, error: "no_changes", message: "Provide at least one budget change." }
    end

    proposal = AiProposal.propose_budget_adjust!(
      family: family,
      user: user,
      arguments: params,
      source: "draft_tool"
    )
    {
      pending_approval: true,
      proposal_id: proposal.id,
      summary: proposal.summary,
      message: "Budget adjustment waiting for Approve / Edit / Dismiss."
    }
  end
end
