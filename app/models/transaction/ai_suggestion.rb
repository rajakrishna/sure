class Transaction::AiSuggestion
  def initialize(transaction:, family:, user:)
    @transaction = transaction
    @family = family
    @user = user
    @entry = transaction.entry
  end

  def explain
    Assistant::Function::ExplainTransaction.new(user).call("transaction_id" => transaction.id)
  end

  def propose!(kind)
    case kind.to_s
    when "categorize", "suggest"
      propose_categorize!
    when "split"
      propose_split!
    when "rule"
      propose_rule!
    else
      raise ArgumentError, "Unknown AI action: #{kind}"
    end
  end

  private
    attr_reader :transaction, :family, :user, :entry

    def propose_categorize!
      category = suggested_category
      return if category.blank?

      AiProposal.propose_categorize!(
        family: family,
        transaction: transaction,
        category_id: category.id,
        source: "auto_categorize",
        user: user,
        reason: I18n.t("transactions.ai_actions.categorize_reason", name: category.display_name)
      )
      pending_proposal("categorize")
    end

    def propose_split!
      return unless transaction.splittable?

      half = (entry.amount.to_d / 2).round(2)
      remainder = entry.amount.to_d - half
      AiProposal.propose_split!(
        family: family,
        transaction: transaction,
        source: "draft_tool",
        user: user,
        splits: [
          { "name" => entry.name, "amount" => half, "category_id" => transaction.category_id },
          { "name" => entry.name, "amount" => remainder, "category_id" => transaction.category_id }
        ]
      )
    end

    def propose_rule!
      category = transaction.category || suggested_category
      return if category.blank? || entry.name.blank?

      family.ai_proposals.create!(
        user: user,
        source: "rule_suggest",
        kind: "create_rule",
        function_name: "create_rule",
        target_type: "Transaction",
        target_id: transaction.id,
        payload: {
          "entry_name" => entry.name,
          "arguments" => {
            "name" => entry.name,
            "match_value" => entry.name,
            "category_id" => category.id
          }
        }
      )
    end

    def pending_proposal(kind)
      family.ai_proposals.pending.find_by(kind: kind, target_type: "Transaction", target_id: transaction.id)
    end

    def suggested_category
      return transaction.category if transaction.category.present?

      similar = similar_transactions.detect { |other| other.category_id.present? }
      return similar.category if similar&.category

      family.categories.alphabetically.first
    end

    def similar_transactions
      scope = family.transactions.joins(:entry).where.not(id: transaction.id)
      if transaction.merchant_id.present?
        scope.where(merchant_id: transaction.merchant_id).limit(8)
      elsif entry.name.present?
        scope.where("LOWER(entries.name) = ?", entry.name.downcase).limit(8)
      else
        Transaction.none
      end
    end

end
