class Rule::ExampleMatcher
  Example = Data.define(
    :name, :amount, :transaction_type, :merchant_id, :category_id,
    :tag_ids, :notes, :details, :account_id, :kind
  ) do
    def self.from_params(params)
      raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
      raw = raw.stringify_keys
      example = raw["example"] || raw

      new(
        name: example["name"].to_s,
        amount: example["amount"].presence&.to_d,
        transaction_type: example["transaction_type"].presence,
        merchant_id: example["merchant_id"].presence,
        category_id: example["category_id"].presence,
        tag_ids: Array(example["tag_ids"]).compact_blank,
        notes: example["notes"].to_s,
        details: example["details"].to_s,
        account_id: example["account_id"].presence,
        kind: example["kind"].presence
      )
    end
  end

  Sample = Data.define(:id, :name, :amount, :date, :category_name)

  def initialize(rule)
    @rule = rule
  end

  def match?(example)
    example = Example.from_params(example) unless example.is_a?(Example)
    conditions = rule.conditions.reject(&:marked_for_destruction?)
    return true if conditions.empty?

    conditions.all? { |condition| matches_condition?(condition, example) }
  end

  def preview(limit: 5)
    scope = rule.matching_scope
    {
      match_count: scope.except(:limit, :offset).count,
      samples: scope.includes(:entry, :category).limit(limit).map { |transaction| serialize_sample(transaction) }
    }
  end

  private
    attr_reader :rule

    def matches_condition?(condition, example)
      if condition.compound?
        subs = condition.sub_conditions.reject(&:marked_for_destruction?)
        return true if subs.empty?

        if condition.operator == "or"
          subs.any? { |sub| matches_condition?(sub, example) }
        else
          subs.all? { |sub| matches_condition?(sub, example) }
        end
      else
        matches_filter?(condition, example)
      end
    end

    def matches_filter?(condition, example)
      operator = condition.operator
      expected = condition.value

      case condition.condition_type
      when "transaction_name"
        compare_text(example.name, operator, expected)
      when "transaction_notes"
        compare_text(example.notes, operator, expected)
      when "transaction_details"
        compare_details(example.details, operator, expected)
      when "transaction_amount"
        return false if example.amount.nil?

        compare_number(example.amount.abs, operator, expected)
      when "transaction_type"
        example.transaction_type.to_s == expected.to_s
      when "transaction_merchant"
        compare_select(example.merchant_id, operator, expected)
      when "transaction_category"
        compare_select(example.category_id, operator, expected)
      when "transaction_account"
        compare_select(example.account_id, operator, expected)
      when "transaction_tag"
        compare_tags(example.tag_ids, operator, expected)
      else
        true
      end
    end

    def compare_text(actual, operator, expected)
      normalized = actual.to_s.gsub(/\s+/, " ").strip
      needle = expected.to_s.gsub(/\s+/, " ").strip

      case operator
      when "like"
        normalized.downcase.include?(needle.downcase)
      when "not_like"
        needle.blank? || !normalized.downcase.include?(needle.downcase)
      when "="
        normalized.casecmp?(needle)
      when "!="
        !normalized.casecmp?(needle)
      when "is_null"
        normalized.blank?
      when "is_not_null"
        normalized.present?
      else
        false
      end
    end

    def compare_number(actual, operator, expected)
      value = expected.to_d

      case operator
      when ">" then actual > value
      when ">=" then actual >= value
      when "<" then actual < value
      when "<=" then actual <= value
      when "=" then actual == value
      when "!=" then actual != value
      else
        false
      end
    end

    def compare_select(actual, operator, expected)
      case operator
      when "="
        actual.to_s == expected.to_s
      when "!="
        actual.to_s != expected.to_s
      when "is_null"
        actual.blank?
      when "is_not_null"
        actual.present?
      else
        false
      end
    end

    def compare_tags(tag_ids, operator, expected)
      ids = Array(tag_ids).map(&:to_s)

      case operator
      when "="
        ids.include?(expected.to_s)
      when "is_null"
        ids.empty?
      else
        false
      end
    end

    def compare_details(actual, operator, expected)
      text = actual.to_s

      case operator
      when "is_null"
        text.blank? || text == "{}"
      when "like"
        text.downcase.include?(expected.to_s.downcase)
      when "="
        text.include?(expected.to_s)
      else
        false
      end
    end

    def serialize_sample(transaction)
      entry = transaction.entry
      Sample.new(
        id: transaction.id,
        name: entry&.name,
        amount: entry&.amount,
        date: entry&.date,
        category_name: transaction.category&.name
      )
    end
end
