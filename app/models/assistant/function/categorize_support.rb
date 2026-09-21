module Assistant::Function::CategorizeSupport
  MAX_UPDATES = 100
  DEFAULT_UNCATEGORIZED_PAGE_SIZE = 40
  TOP_CATEGORY_LIMIT = 10

  private
    def accessible_account_ids
      user.accessible_accounts.visible.select(:id)
    end

    # Same filters as Entry.uncategorized_transactions, plus the caller's
    # account-access scope. Split out so categorized/uncategorized counts share
    # one definition of "categorizable".
    def categorizable_entries
      Entry.where(account_id: accessible_account_ids)
        .joins(:account)
        .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
        .where(accounts: { status: %w[draft active] })
        .where.not(transactions: { kind: Transaction::UNCATEGORIZED_EXCLUDED_KINDS })
        .where(entries: { excluded: false })
    end

    def uncategorized_entries
      categorizable_entries.where(transactions: { category_id: nil })
    end

    def categorized_entries
      categorizable_entries.where.not(transactions: { category_id: nil })
    end

    def find_accessible_transaction(id)
      return nil unless valid_uuid?(id)

      family.transactions
        .joins(:entry)
        .where(entries: { account_id: accessible_account_ids })
        .find_by(id: id)
    end

    def permitted_to_categorize?(account)
      account.permission_for(user).in?([ :owner, :full_control, :read_write ])
    end

    def parse_date(value)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def serialize_uncategorized(entry, transaction = nil)
      transaction ||= entry.transaction
      {
        id: transaction.id,
        **Assistant::DateText.payload(entry.date, family: family),
        name: entry.name,
        amount: entry.amount.abs,
        currency: entry.currency,
        classification: entry.classification,
        merchant: transaction.merchant&.name,
        account: entry.account.name
      }
    end

    def error(key, message, extras = {})
      { success: false, error: key, message: message }.merge(extras)
    end
end
