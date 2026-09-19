class Family::RefundMatcher
  LOOKBACK_DAYS = 90
  AMOUNT_TOLERANCE = BigDecimal("0.02")
  MAX_PROPOSALS = 20

  def initialize(family)
    @family = family
  end

  def match!
    created = 0

    expenses.each do |expense|
      break if created >= MAX_PROPOSALS

      refund = find_refund_for(expense)
      next unless refund
      next if already_proposed?(expense, refund)

      family.ai_proposals.create!(
        source: "refund_match",
        kind: "refund_match",
        target_type: "Transaction",
        target_id: expense.id,
        payload: {
          "expense_transaction_id" => expense.id,
          "refund_transaction_id" => refund.id,
          "expense_name" => expense.entry.name,
          "refund_name" => refund.entry.name,
          "amount" => expense.entry.amount.abs.to_s,
          "currency" => expense.entry.currency,
          "expense_date" => expense.entry.date.iso8601,
          "refund_date" => refund.entry.date.iso8601
        }
      )
      created += 1
    end

    created
  end

  private
    attr_reader :family

    def expenses
      candidate_scope
        .where("entries.amount > 0")
        .where("entries.date >= ?", LOOKBACK_DAYS.days.ago.to_date)
        .includes(:merchant, :tags, entry: :account)
        .order("entries.date DESC")
        .limit(200)
    end

    def inflows
      @inflows ||= candidate_scope
        .where("entries.amount < 0")
        .where("entries.date >= ?", LOOKBACK_DAYS.days.ago.to_date)
        .includes(:merchant, :tags, entry: :account)
        .to_a
    end

    def candidate_scope
      family.transactions
        .joins(:entry)
        .merge(Entry.where(excluded: false))
        .where.not(kind: Transaction::TRANSFER_KINDS)
    end

    def find_refund_for(expense)
      amount = expense.entry.amount.abs
      inflows.find do |inflow|
        next if inflow.entry.account_id != expense.entry.account_id
        next if inflow.entry.date < expense.entry.date
        next unless amounts_match?(amount, inflow.entry.amount.abs)
        next unless similar_payee?(expense, inflow)
        next if tagged_refund?(inflow) && tagged_refund?(expense)

        true
      end
    end

    def amounts_match?(left, right)
      (left - right).abs <= [ AMOUNT_TOLERANCE, left * BigDecimal("0.01") ].max
    end

    def similar_payee?(left, right)
      a = normalize(left.merchant&.name.presence || left.entry.name)
      b = normalize(right.merchant&.name.presence || right.entry.name)
      return false if a.blank? || b.blank?
      return true if a == b
      return true if a.include?(b) || b.include?(a)

      DidYouMean::Levenshtein.distance(a, b) <= [ 3, (a.length * 0.25).ceil ].max
    end

    def normalize(value)
      value.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def tagged_refund?(transaction)
      transaction.tags.any? { |tag| tag.name.casecmp?("Refund") }
    end

    def already_proposed?(expense, refund)
      family.ai_proposals.pending.where(kind: "refund_match").any? do |proposal|
        ids = [
          proposal.payload["expense_transaction_id"],
          proposal.payload["refund_transaction_id"]
        ].map(&:to_s)
        ids.include?(expense.id.to_s) || ids.include?(refund.id.to_s)
      end
    end
end
