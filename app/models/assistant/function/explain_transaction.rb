class Assistant::Function::ExplainTransaction < Assistant::Function
  include Assistant::Function::Presentable
  class << self
    def name
      "explain_transaction"
    end

    def description
      <<~INSTRUCTIONS
        Explain a single transaction in plain language: merchant, category,
        amount, related rules or AI suggestions, and whether it looks unusual.
        Never change the transaction.
      INSTRUCTIONS
    end
  end

  def params_schema
    {
      type: "object",
      properties: {
        transaction_id: {
          type: "string",
          description: "The transaction id to explain"
        }
      },
      required: [ "transaction_id" ]
    }
  end

  def call(params = {})
    transaction = family.transactions.find_by(id: params["transaction_id"])
    return { success: false, error: "not_found", message: "Transaction not found." } unless transaction

    entry = transaction.entry
    proposal = family.ai_proposals.pending.find_by(target_type: "Transaction", target_id: transaction.id)
    links = [ deep_link(I18n.t("assistant.deep_links.transaction"), transaction_path(entry)) ]
    if transaction.merchant.present?
      links << deep_link(transaction.merchant.name, transactions_path(q: { merchants: [ transaction.merchant.name ] }))
    end
    if transaction.category.present?
      links << deep_link(transaction.category.display_name, transactions_path(q: { categories: [ transaction.category.name ] }))
    end
    if entry&.account.present?
      links << deep_link(entry.account.name, account_path(entry.account))
    end

    with_presentation({
      success: true,
      transaction_id: transaction.id,
      name: entry&.name,
      **Assistant::DateText.payload(entry&.date, family: family),
      amount: entry&.amount,
      currency: entry&.currency,
      category: transaction.category&.display_name,
      merchant: transaction.merchant&.name,
      reviewed: transaction.reviewed?,
      intelligence_source: transaction.intelligence_source,
      pending_suggestion: proposal&.summary,
      notes: entry&.notes
    }, deep_links: links)
  end
end
