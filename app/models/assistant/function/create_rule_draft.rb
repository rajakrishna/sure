class Assistant::Function::CreateRuleDraft < Assistant::Function
  class << self
    def name
      "create_rule_draft"
    end

    def description
      <<~INSTRUCTIONS
        Drafts a transaction rule for human approval. Never writes the rule
        until the user Approves the card. Prefer this over create_rule.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    Assistant::Function::CreateRule.new(user).params_schema
  end

  def call(params = {})
    match_value = params["match_value"].to_s.strip.presence || params["value"].to_s.strip
    return error("match_value_required", "Provide match_value.") if match_value.blank?

    category_id = params["category_id"].presence || params["action_value"].presence
    return error("category_required", "Provide category_id.") unless valid_uuid?(category_id)
    return error("invalid_category", "category_id does not belong to the user's family.") unless family.categories.exists?(id: category_id)

    proposal = AiProposal.record_from_tool!(
      family: family,
      user: user,
      chat: nil,
      function: Assistant::Function::CreateRule.new(user),
      arguments: params,
      source: "draft_tool"
    )
    {
      pending_approval: true,
      proposal_id: proposal.id,
      summary: proposal.summary,
      message: "Rule draft waiting for Approve / Edit / Dismiss."
    }
  end

  private
    def error(key, message)
      { success: false, error: key, message: message }
    end
end
