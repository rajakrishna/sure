class Transaction::Inbox
  def initialize(family:, user:, assignee_id: nil, account_ids: nil)
    @family = family
    @user = user
    @assignee_id = assignee_id
    @account_ids = account_ids
  end

  def transactions
    scope = uncategorized
    scope = scope.where(assignee_id: assignee_id) if assignee_id.present?
    scope.reverse_chronological.includes({ entry: :account }, :category, :merchant, :assignee)
  end

  def assigned_to_user_count
    uncategorized.where(assignee_id: user.id).count
  end

  def self.uncategorized_for(family, account_ids: nil)
    scope = family.transactions
      .where(category_id: nil, reviewed_at: nil)
      .where.not(kind: Transaction::UNCATEGORIZED_EXCLUDED_KINDS)
      .where(entries: { excluded: false })
      .where(accounts: { status: %w[draft active] })
    scope = scope.where(entries: { account_id: account_ids }) if account_ids.present?
    scope
  end

  private
    attr_reader :family, :user, :assignee_id, :account_ids

    def uncategorized
      self.class.uncategorized_for(family, account_ids: filtered_account_ids)
    end

    def filtered_account_ids
      accessible = user.accessible_accounts.select(:id)
      return accessible if account_ids.blank?

      user.accessible_accounts.where(id: account_ids).select(:id)
    end
end
