class Chat::ComposerCatalog
  ACCOUNT_LIMIT = 40
  TRANSACTION_LIMIT = 40
  GOAL_LIMIT = 20

  def self.for(user)
    new(user).as_json
  end

  def initialize(user)
    @user = user
  end

  def as_json
    {
      accounts: accounts,
      transactions: transactions,
      goals: goals
    }
  end

  private
    attr_reader :user

    def accounts
      user.accessible_accounts.visible.order(:name).limit(ACCOUNT_LIMIT).map do |account|
        {
          type: "account",
          id: account.id,
          name: account.name,
          subtitle: account.accountable_type
        }
      end
    end

    def transactions
      Transaction
        .joins(entry: :account)
        .includes(:merchant, entry: :account)
        .merge(Entry.where(account_id: user.accessible_accounts.visible.select(:id)))
        .merge(Entry.order(date: :desc, created_at: :desc))
        .limit(TRANSACTION_LIMIT)
        .map do |transaction|
          entry = transaction.entry
          name = transaction.merchant&.name.presence || entry.name
          {
            type: "transaction",
            id: transaction.id,
            name: name,
            subtitle: "#{entry.amount_money.abs.format} · #{entry.date} · #{entry.account.name}"
          }
        end
    end

    def goals
      return [] unless user.preview_features_enabled?

      user.family.goals.includes(:linked_accounts).where.not(state: "archived").order(:name).limit(GOAL_LIMIT).map do |goal|
        {
          type: "goal",
          id: goal.id,
          name: goal.name,
          subtitle: "#{goal.current_balance_money.format} of #{goal.target_amount_money.format}"
        }
      end
    end
end
