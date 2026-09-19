class Assistant::Function::SplitTransactionDraft < Assistant::Function
  class << self
    def name
      "split_transaction_draft"
    end

    def description
      <<~INSTRUCTIONS
        Drafts a split of one transaction into two or more lines. Nothing is
        written until the user Approves. Amounts must use the same sign as the
        parent entry (negative inflow, positive outflow) and sum to the parent.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "transaction_id", "splits" ],
      properties: {
        transaction_id: { type: "string", description: "Transaction ID from get_transactions" },
        splits: {
          type: "array",
          minItems: 2,
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              amount: { type: "number" },
              category_id: { type: [ "string", "null" ] }
            },
            required: [ "name", "amount" ],
            additionalProperties: false
          }
        }
      }
    )
  end

  def call(params = {})
    transaction = family.transactions.find_by(id: params["transaction_id"])
    return error("not_found", "Transaction not found.") unless transaction
    return error("not_splittable", "This transaction cannot be split.") unless transaction.splittable?

    splits = Array(params["splits"]).map do |split|
      {
        "name" => split["name"].to_s,
        "amount" => split["amount"].to_s,
        "category_id" => split["category_id"]
      }
    end
    return error("too_few", "Provide at least two split lines.") if splits.size < 2

    proposal = AiProposal.propose_split!(
      family: family,
      user: user,
      transaction: transaction,
      splits: splits,
      source: "draft_tool"
    )
    {
      pending_approval: true,
      proposal_id: proposal.id,
      summary: proposal.summary,
      message: "Split draft waiting for Approve / Edit / Dismiss."
    }
  end

  private
    def error(key, message)
      { success: false, error: key, message: message }
    end
end
