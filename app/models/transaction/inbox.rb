class Transaction::Inbox
  def initialize(family:, user:, assignee_id: nil, account_ids: nil)
    @family = family
    @user = user
    @assignee_id = assignee_id
    @account_ids = account_ids
  end

  def transactions
    scope = family.transactions.merge(Entry.uncategorized_transactions)
    scope = scope.where(entries: { account_id: account_ids }) if account_ids
    accessible = user.accessible_accounts.select(:id)
    scope = scope.where(entries: { account_id: accessible })
    scope = scope.where(assignee_id: assignee_id) if assignee_id.present?
    scope.reverse_chronological.includes({ entry: :account }, :category, :merchant, :assignee)
  end

  def assigned_to_user_count
    family.transactions
      .where(assignee_id: user.id)
      .merge(Entry.uncategorized_transactions)
      .where(entries: { account_id: user.accessible_accounts.select(:id) })
      .count
  end

  private
    attr_reader :family, :user, :assignee_id, :account_ids
end
