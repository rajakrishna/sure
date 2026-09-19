class AiProposal < ApplicationRecord
  SOURCES = %w[chat auto_categorize bayes].freeze
  KINDS = %w[categorize create_rule mutation].freeze
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

  def self.propose_categorize!(family:, transaction:, category_id:, source:, user: nil)
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
        "suggested_rule" => suggested_rule_payload(entry, category)
      }
    )
    proposal.save!
    true
  end

  def self.record_from_tool!(family:, user:, chat:, function:, arguments:)
    kind = function.name == "create_rule" ? "create_rule" : "mutation"
    family.ai_proposals.create!(
      user: user,
      chat: chat,
      source: "chat",
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
      elsif payload["arguments"].is_a?(Hash)
        payload["arguments"].merge!(attrs["arguments"] || {})
      else
        payload.merge!(attrs)
      end
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
