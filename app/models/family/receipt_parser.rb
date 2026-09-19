class Family::ReceiptParser
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You read a receipt photo and return JSON only:
    {"merchant": string, "total": number, "currency": string, "splits": [{"name": string, "amount": number, "category_hint": string}]}
    Amounts are positive numbers in the receipt currency. Splits must sum to total.
    If you cannot read the receipt, return {"error": "unreadable"}.
  PROMPT

  Result = Data.define(:merchant, :total, :splits, :error)

  def initialize(family:, transaction:)
    @family = family
    @transaction = transaction
  end

  def parse
    attachment = image_attachment
    return Result.new(merchant: nil, total: nil, splits: [], error: "no_image") unless attachment
    return Result.new(merchant: nil, total: nil, splits: [], error: "no_provider") unless provider

    payload = provider.chat_response(
      "Parse this receipt into draft splits.",
      model: provider.class.effective_model,
      instructions: SYSTEM_PROMPT,
      family: family
    )
    return fallback_from_entry unless payload.success?

    text = payload.data.messages.filter_map(&:output_text).join(" ")
    parsed = JSON.parse(text.[](/\{.*\}/m) || text)
    if parsed["error"].present?
      return Result.new(merchant: nil, total: nil, splits: [], error: parsed["error"])
    end

    Result.new(
      merchant: parsed["merchant"],
      total: parsed["total"],
      splits: Array(parsed["splits"]),
      error: nil
    )
  rescue
    fallback_from_entry
  end

  def propose!
    result = parse
    return result if result.error.present? && result.splits.blank?

    splits = normalized_splits(result)
    return Result.new(merchant: result.merchant, total: result.total, splits: [], error: "empty_splits") if splits.size < 2

    AiProposal.propose_split!(
      family: family,
      user: nil,
      transaction: transaction,
      splits: splits,
      source: "receipt_vision"
    )
    result
  end

  private
    attr_reader :family, :transaction

    def image_attachment
      transaction.attachments.blobs.find { |blob| blob.content_type.to_s.start_with?("image/") }
    end

    def provider
      @provider ||= Provider::Registry.preferred_llm_provider
    end

    def fallback_from_entry
      entry = transaction.entry
      amount = entry.amount.to_d.abs
      half = (amount / 2).round(2)
      remainder = (amount - half).round(2)
      Result.new(
        merchant: entry.name,
        total: amount,
        splits: [
          { "name" => entry.name, "amount" => half.to_f, "category_hint" => transaction.category&.name },
          { "name" => I18n.t("receipt_parser.other"), "amount" => remainder.to_f, "category_hint" => nil }
        ],
        error: "heuristic"
      )
    end

    def normalized_splits(result)
      entry = transaction.entry
      parent_amount = entry.amount.to_d
      sign = parent_amount.negative? ? -1 : 1
      raw = result.splits.filter_map do |split|
        amount = split["amount"].to_d.abs
        next if amount.zero?

        {
          "name" => split["name"].presence || entry.name,
          "amount" => (amount * sign).to_s,
          "category_id" => category_id_for(split["category_hint"])
        }
      end
      return [] if raw.size < 2

      sum = raw.sum { |split| split["amount"].to_d }
      unless sum == parent_amount
        delta = parent_amount - sum
        raw.last["amount"] = (raw.last["amount"].to_d + delta).to_s
      end
      raw
    end

    def category_id_for(hint)
      return if hint.blank?

      family.categories.where("LOWER(name) = ?", hint.to_s.downcase).pick(:id)
    end
end
