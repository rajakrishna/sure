class AiProposal < ApplicationRecord
  SOURCES = %w[chat auto_categorize bayes rule_suggest refund_match merchant_detect draft_tool receipt_vision mcp idle_cash].freeze
  KINDS = %w[categorize create_rule mutation refund_match set_merchant split budget_adjust].freeze
  STATUSES = %w[pending approved dismissed].freeze

  belongs_to :family
  belongs_to :user, optional: true
  belongs_to :chat, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payload, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def self.propose_merchant!(family:, transaction:, merchant_id:, merchant_name:, source: "merchant_detect", website_url: nil, logo_url: nil)
    proposal = family.ai_proposals.pending.find_or_initialize_by(
      kind: "set_merchant",
      target_type: "Transaction",
      target_id: transaction.id
    )
    entry = transaction.entry
    proposal.assign_attributes(
      source: source,
      payload: {
        "transaction_id" => transaction.id,
        "merchant_id" => merchant_id,
        "merchant_name" => merchant_name,
        "website_url" => website_url,
        "logo_url" => logo_url,
        "entry_name" => entry&.name,
        "amount" => entry&.amount,
        "date" => entry&.date&.iso8601
      }
    )
    proposal.save!
    true
  end

  def self.propose_categorize!(family:, transaction:, category_id:, source:, user: nil, confidence: nil, reason: nil, alternatives: [])
    category = family.categories.find_by(id: category_id)
    return false unless category

    entry = transaction.entry
    proposal = family.ai_proposals.pending.find_or_initialize_by(
      kind: "categorize",
      target_type: "Transaction",
      target_id: transaction.id
    )

    proposal.assign_attributes(
      source: source,
      user: user,
      payload: {
        "transaction_id" => transaction.id,
        "category_id" => category.id,
        "category_name" => category.name,
        "entry_name" => entry&.name,
        "amount" => entry&.amount,
        "date" => entry&.date&.iso8601,
        "confidence" => confidence,
        "reason" => reason,
        "alternatives" => Array(alternatives),
        "suggested_rule" => suggested_rule_payload(entry, category)
      }
    )
    proposal.save!
    true
  end

  def self.bulk_approve!(family:, ids:, actor:)
    family.ai_proposals.pending.where(id: ids).find_each.map do |proposal|
      proposal.approve!(actor)
      proposal
    end
  end

  def self.bulk_dismiss!(family:, ids:, actor:)
    family.ai_proposals.pending.where(id: ids).find_each.map do |proposal|
      proposal.dismiss!(actor)
      proposal
    end
  end

  def confidence
    payload["confidence"]&.to_f
  end

  def reason
    payload["reason"]
  end

  def alternatives
    Array(payload["alternatives"])
  end

  def self.propose_split!(family:, transaction:, splits:, source: "draft_tool", user: nil)
    entry = transaction.entry
    proposal = family.ai_proposals.pending.find_or_initialize_by(
      kind: "split",
      target_type: "Transaction",
      target_id: transaction.id
    )
    proposal.assign_attributes(
      source: source,
      user: user,
      payload: {
        "transaction_id" => transaction.id,
        "entry_name" => entry&.name,
        "amount" => entry&.amount,
        "date" => entry&.date&.iso8601,
        "splits" => splits
      }
    )
    proposal.save!
    proposal
  end

  def self.propose_budget_adjust!(family:, arguments:, user: nil, source: "draft_tool", target_id: nil)
    family.ai_proposals.create!(
      user: user,
      source: source,
      kind: "budget_adjust",
      function_name: "update_budget",
      target_id: target_id,
      payload: {
        "arguments" => arguments,
        "function_name" => "update_budget"
      }
    )
  end

  def self.record_from_tool!(family:, user:, chat:, function:, arguments:, source: "chat")
    kind = function.name == "create_rule" ? "create_rule" : "mutation"
    family.ai_proposals.create!(
      user: user,
      chat: chat,
      source: source,
      kind: kind,
      function_name: function.name,
      payload: {
        "arguments" => arguments,
        "function_name" => function.name
      }
    )
  end

  def approve!(actor, attributes = {}, create_rule: false)
    raise ArgumentError, "Proposal is not pending" unless pending?

    merge_payload!(attributes) if attributes.present?

    case kind
    when "categorize"
      apply_categorize!
      apply_suggested_rule!(actor) if create_rule
    when "create_rule"
      apply_create_rule!(actor)
    when "split"
      apply_split!
    when "budget_adjust"
      apply_budget_adjust!(actor)
    when "refund_match"
      apply_refund_match!
    when "set_merchant"
      apply_merchant!
    else
      apply_function!(actor)
    end

    update!(status: "approved", reviewed_at: Time.current, reviewed_by: actor)
  end

  def dismiss!(actor)
    raise ArgumentError, "Proposal is not pending" unless pending?

    update!(status: "dismissed", reviewed_at: Time.current, reviewed_by: actor)
  end

  def update_payload!(attributes)
    raise ArgumentError, "Proposal is not pending" unless pending?

    merge_payload!(attributes)
    save!
  end

  def summary
    case kind
    when "categorize"
      I18n.t("ai_proposals.summaries.categorize",
        name: payload["entry_name"].presence || I18n.t("ai_proposals.summaries.unnamed_transaction"),
        category: payload["category_name"])
    when "create_rule"
      I18n.t("ai_proposals.summaries.create_rule",
        name: payload.dig("arguments", "name").presence || payload["entry_name"].presence || I18n.t("ai_proposals.summaries.unnamed_rule"))
    when "refund_match"
      I18n.t("ai_proposals.summaries.refund_match",
        expense: payload["expense_name"],
        refund: payload["refund_name"])
    when "set_merchant"
      I18n.t("ai_proposals.summaries.set_merchant",
        name: payload["entry_name"].presence || I18n.t("ai_proposals.summaries.unnamed_transaction"),
        merchant: payload["merchant_name"])
    when "split"
      I18n.t("ai_proposals.summaries.split",
        name: payload["entry_name"].presence || I18n.t("ai_proposals.summaries.unnamed_transaction"),
        count: Array(payload["splits"]).size)
    when "budget_adjust"
      I18n.t("ai_proposals.summaries.budget_adjust")
    else
      I18n.t("ai_proposals.summaries.mutation", function: human_function_name)
    end
  end

  def target_transaction
    return unless target_type == "Transaction" && target_id.present?

    family.transactions.find_by(id: target_id)
  end

  def suggested_rule?
    payload["suggested_rule"].present? || kind == "create_rule"
  end

  private
    def self.suggested_rule_payload(entry, category)
      return nil if entry&.name.blank?

      {
        "name" => entry.name,
        "condition_type" => "transaction_name",
        "operator" => "like",
        "value" => entry.name,
        "action_type" => "set_transaction_category",
        "action_value" => category.id
      }
    end
    private_class_method :suggested_rule_payload

    def merge_payload!(attributes)
      attrs = attributes.respond_to?(:to_unsafe_h) ? attributes.to_unsafe_h : attributes
      attrs = attrs.stringify_keys

      if kind == "categorize" && attrs["category_id"].present?
        category = family.categories.find(attrs["category_id"])
        payload["category_id"] = category.id
        payload["category_name"] = category.name
        if payload["suggested_rule"].is_a?(Hash)
          payload["suggested_rule"]["action_value"] = category.id
        end
      elsif kind == "create_rule"
        payload["arguments"] ||= {}
        %w[name match_value category_id transaction_type].each do |key|
          payload["arguments"][key] = attrs[key] if attrs[key].present?
        end
      elsif kind == "split" && attrs["splits"].present?
        payload["splits"] = attrs["splits"]
      elsif kind == "budget_adjust"
        payload["arguments"] ||= {}
        payload["arguments"].merge!(attrs["arguments"] || attrs)
      elsif payload["arguments"].is_a?(Hash)
        payload["arguments"].merge!(attrs["arguments"] || {})
      else
        payload.merge!(attrs)
      end
    end

    def apply_refund_match!
      expense = family.transactions.find_by(id: payload["expense_transaction_id"])
      refund = family.transactions.find_by(id: payload["refund_transaction_id"])
      raise ActiveRecord::RecordNotFound, "Refund pair not found" unless expense && refund

      tag = family.tags.find_or_create_by!(name: I18n.t("ai_proposals.refund_tag")) do |record|
        record.color = Tag::COLORS.first
      end
      [ expense, refund ].each do |transaction|
        transaction.tags << tag unless transaction.tags.include?(tag)
        entry = transaction.entry
        note = I18n.t("ai_proposals.refund_note", counterpart: counterpart_name(transaction, expense, refund))
        next if entry.notes.to_s.include?(note)

        entry.update!(notes: [ entry.notes.presence, note ].compact.join("\n"))
      end
    end

    def counterpart_name(transaction, expense, refund)
      transaction.id == expense.id ? refund.entry.name : expense.entry.name
    end

    def apply_merchant!
      transaction = target_transaction
      raise ActiveRecord::RecordNotFound, "Transaction not found" unless transaction

      merchant_id = payload["merchant_id"].presence
      merchant_id ||= find_or_create_merchant_from_payload&.id
      raise ArgumentError, "Merchant missing" if merchant_id.blank?

      transaction.enrich_attribute(:merchant_id, merchant_id, source: "ai")
      transaction.lock_attr!(:merchant_id)
    end

    def find_or_create_merchant_from_payload
      name = payload["merchant_name"].to_s.strip
      return if name.blank?

      existing = ProviderMerchant.find_by(source: "ai", name: name)
      return existing if existing

      ProviderMerchant.create!(
        source: "ai",
        name: name,
        website_url: payload["website_url"],
        logo_url: payload["logo_url"]
      )
    end

    def apply_split!
      transaction = target_transaction
      raise ActiveRecord::RecordNotFound, "Transaction not found" unless transaction
      raise ArgumentError, "Transaction is not splittable" unless transaction.splittable?

      entry = transaction.entry
      splits = Array(payload["splits"]).map do |split|
        {
          name: split["name"],
          amount: split["amount"].to_d,
          category_id: split["category_id"].presence,
          excluded: split["excluded"]
        }
      end
      raise ArgumentError, "Split needs at least two lines" if splits.size < 2

      entry.split!(splits)
      entry.sync_account_later
    end

    def apply_budget_adjust!(actor)
      result = Assistant::Function::UpdateBudget.new(actor).call(payload["arguments"] || {})
      if result.is_a?(Hash) && (result[:success] == false || result["success"] == false)
        raise ArgumentError, result[:message] || result["message"] || "Budget update failed"
      end
      result
    end

    def apply_categorize!
      transaction = target_transaction
      raise ActiveRecord::RecordNotFound, "Transaction not found" unless transaction

      category = family.categories.find(payload["category_id"])
      source_name = source == "bayes" ? "bayes" : "ai"
      transaction.enrich_attribute(:category_id, category.id, source: source_name)
      transaction.lock_attr!(:category_id)
    end

    def apply_create_rule!(actor)
      activate_created_rule!(call_create_rule!(actor, payload["arguments"] || {}))
    end

    def apply_suggested_rule!(actor)
      suggested = payload["suggested_rule"]
      return if suggested.blank?

      activate_created_rule!(
        call_create_rule!(actor, {
          "name" => suggested["name"],
          "match_value" => suggested["value"],
          "category_id" => suggested["action_value"]
        })
      )
    end

    def call_create_rule!(actor, args)
      result = Assistant::Function::CreateRule.new(actor).call(args)
      if result.is_a?(Hash) && (result[:success] == false || result["success"] == false)
        raise ArgumentError, result[:message] || result["message"] || result[:error] || result["error"] || "Function failed"
      end
      result
    end

    def activate_created_rule!(result)
      rule_id = result.is_a?(Hash) ? (result[:rule_id] || result["rule_id"]) : nil
      return unless rule_id

      family.rules.where(id: rule_id).update_all(active: true, updated_at: Time.current)
    end

    def apply_function!(actor)
      fn_class = Assistant.function_classes(actor).find { |klass| klass.name == function_name }
      fn_class ||= Assistant::Function::CreateRule if function_name == "create_rule"
      raise ArgumentError, "Unknown function: #{function_name}" unless fn_class

      result = fn_class.new(actor).call(payload["arguments"] || {})
      if result.is_a?(Hash) && (result[:success] == false || result["success"] == false)
        raise ArgumentError, result[:message] || result["message"] || result[:error] || result["error"] || "Function failed"
      end
      result
    end

    def human_function_name
      (function_name || kind).to_s.tr("_", " ")
    end
end
