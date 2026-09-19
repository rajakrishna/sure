class Family::RuleSuggestFromCorrection
  THRESHOLD = 3
  LOOKBACK_DAYS = 30

  def initialize(family)
    @family = family
  end

  def record!(transaction)
    return 0 unless transaction&.category_id.present?

    propose_for(payee_for(transaction), transaction.category)
  end

  def scan_recent
    grouped = family.transactions
      .joins(:entry)
      .where.not(category_id: nil)
      .where("entries.date >= ?", LOOKBACK_DAYS.days.ago.to_date)
      .group(Arel.sql("COALESCE(transactions.merchant_id::text, LOWER(entries.name))"), :category_id)
      .having("COUNT(*) >= ?", THRESHOLD)
      .count

    created = 0
    grouped.each do |(payee_key, category_id), _count|
      category = family.categories.find_by(id: category_id)
      next unless category

      created += propose_for(payee_key.to_s, category)
    end
    created
  end

  private
    attr_reader :family

    def payee_for(transaction)
      transaction.merchant_id.presence || transaction.entry&.name.to_s.strip
    end

    def propose_for(payee, category)
      return 0 if payee.blank? || category.blank?

      match_value = match_value_for(payee)
      return 0 if match_value.blank?
      return 0 unless matching_count(payee, category) >= THRESHOLD
      return 0 if existing_rule?(match_value, category)
      return 0 if pending_suggestion?(match_value, category)

      family.ai_proposals.create!(
        source: "rule_suggest",
        kind: "create_rule",
        payload: {
          "arguments" => {
            "name" => match_value,
            "match_value" => match_value,
            "category_id" => category.id
          },
          "entry_name" => match_value
        }
      )
      1
    end

    def match_value_for(payee)
      if uuid?(payee)
        family.merchants.find_by(id: payee)&.name.presence ||
          Merchant.find_by(id: payee)&.name
      else
        name = payee.to_s.strip
        return name if name != name.downcase

        family.entries.where("LOWER(entries.name) = ?", name).order(date: :desc).limit(1).pick(:name).presence || name
      end
    end

    def matching_count(payee, category)
      scope = family.transactions.joins(:entry).where(category_id: category.id)
      if uuid?(payee)
        scope.where(merchant_id: payee).count
      else
        scope.where("LOWER(entries.name) = ?", payee.to_s.downcase).count
      end
    end

    def existing_rule?(match_value, category)
      family.rules
        .joins(:conditions, :actions)
        .where(rule_conditions: { condition_type: "transaction_name", value: match_value })
        .where(rule_actions: { action_type: "set_transaction_category", value: category.id.to_s })
        .exists?
    end

    def pending_suggestion?(match_value, category)
      family.ai_proposals.pending.where(kind: "create_rule", source: "rule_suggest").any? do |proposal|
        args = proposal.payload["arguments"] || {}
        args["match_value"].to_s.casecmp?(match_value.to_s) && args["category_id"].to_s == category.id.to_s
      end
    end

    def uuid?(value)
      UuidFormat.valid?(value.to_s)
    end
end
