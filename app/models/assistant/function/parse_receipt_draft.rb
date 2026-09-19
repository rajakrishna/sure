class Assistant::Function::ParseReceiptDraft < Assistant::Function
  class << self
    def name
      "parse_receipt_draft"
    end

    def description
      <<~INSTRUCTIONS
        Reads a receipt photo attached to a transaction and drafts split lines
        for approval. Never splits the transaction until the user Approves.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "transaction_id" ],
      properties: {
        transaction_id: { type: "string", description: "Transaction ID that has a receipt image attached" }
      }
    )
  end

  def call(params = {})
    transaction = family.transactions.find_by(id: params["transaction_id"])
    return { success: false, error: "not_found", message: "Transaction not found." } unless transaction
    return { success: false, error: "not_splittable", message: "This transaction cannot be split." } unless transaction.splittable?

    result = Family::ReceiptParser.new(family: family, transaction: transaction).propose!
    if result.error.present? && result.splits.blank?
      return { success: false, error: result.error, message: "Could not parse the receipt." }
    end

    proposal = family.ai_proposals.pending.find_by(kind: "split", target_id: transaction.id)
    {
      pending_approval: true,
      proposal_id: proposal&.id,
      merchant: result.merchant,
      message: "Receipt split draft waiting for Approve / Edit / Dismiss."
    }
  end
end
