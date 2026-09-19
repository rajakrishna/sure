class Chat::ComposerContext
  MAX_ITEMS = 8
  TEXT_EXCERPT_BYTES = 4_000

  def self.merge(content, raw_items, user:, attachments: [])
    new(user).merge(content, raw_items, attachments: attachments)
  end

  def initialize(user)
    @user = user
  end

  def merge(content, raw_items, attachments: [])
    blocks = []
    items_block = format_items(raw_items)
    blocks << items_block if items_block.present?
    files_block = format_attachments(attachments)
    blocks << files_block if files_block.present?

    body = content.to_s
    return body if blocks.empty?

    "#{blocks.join("\n\n")}\n\n#{body}".strip
  end

  private
    attr_reader :user

    def format_items(raw_items)
      items = parse_items(raw_items).first(MAX_ITEMS)
      return if items.empty?

      lines = items.filter_map { |item| format_item(item) }
      return if lines.empty?

      "## Attached context\n#{lines.join("\n")}"
    end

    def format_item(item)
      case item["type"]
      when "account"
        format_account(item["id"])
      when "transaction"
        format_transaction(item["id"])
      when "goal"
        format_goal(item["id"])
      when "bill"
        format_bill(item["id"])
      end
    end

    def format_account(id)
      account = user.accessible_accounts.visible.find_by(id: id)
      return unless account

      "- Account: #{account.name} (#{account.accountable_type}, #{account.classification}) — #{account.balance_money.format}"
    end

    def format_transaction(id)
      transaction = family_transactions.find_by(id: id)
      return unless transaction

      entry = transaction.entry
      merchant = transaction.merchant&.name.presence || entry.name
      "- Transaction: #{merchant} — #{entry.amount_money.abs.format} on #{entry.date} (#{entry.account.name})"
    end

    def format_bill(id)
      return if user.family.recurring_transactions_disabled?

      series = user.family.recurring_transactions.accessible_by(user).find_by(id: id)
      return unless series

      "- Bill: #{series.display_name} — #{series.amount_money.abs.format} (#{series.bill_type})"
    end

    def format_goal(id)
      goal = user.family.goals.find_by(id: id)
      return unless goal

      "- Goal: #{goal.name} — #{goal.current_balance_money.format} of #{goal.target_amount_money.format} (#{goal.progress_percent}%)"
    end

    def format_attachments(attachments)
      files = Array(attachments).select { |file| file.respond_to?(:original_filename) }
      return if files.empty?

      lines = files.map do |file|
        excerpt = text_excerpt(file)
        line = "- File: #{file.original_filename} (#{file.content_type})"
        excerpt.present? ? "#{line}\n#{excerpt}" : line
      end

      "## Attached files\n#{lines.join("\n")}"
    end

    def text_excerpt(file)
      return unless file.content_type.to_s.start_with?("text/") || file.content_type == "application/json"

      content = file.read.to_s.byteslice(0, TEXT_EXCERPT_BYTES)
      file.rewind if file.respond_to?(:rewind)
      return if content.blank?

      "```\n#{content.strip}\n```"
    rescue StandardError
      nil
    end

    def parse_items(raw_items)
      parsed = case raw_items
      when String
        raw_items.blank? ? [] : JSON.parse(raw_items)
      when Array
        raw_items
      else
        []
      end

      return [] unless parsed.is_a?(Array)

      parsed.filter_map do |item|
        next unless item.is_a?(Hash)

        type = item["type"] || item[:type]
        id = item["id"] || item[:id]
        next if type.blank? || id.blank?

        { "type" => type.to_s, "id" => id.to_s }
      end
    rescue JSON::ParserError, TypeError
      []
    end

    def family_transactions
      Transaction
        .joins(:entry)
        .merge(Entry.where(account_id: user.accessible_accounts.visible.select(:id)))
    end
end
