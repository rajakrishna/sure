class Family::WealthSnapshot
  Slice = Data.define(:key, :label, :amount, :weight, :classification)
  Group = Data.define(:name, :total, :classification)

  def initialize(family:, user:, account_ids: nil)
    @family = family
    @user = user
    @account_ids = account_ids
  end

  def balance_sheet
    @balance_sheet ||= family.balance_sheet(user: user)
  end

  def net_worth_money
    return balance_sheet.net_worth_money unless filtered?

    Money.new(selected_accounts.assets.sum(:balance) - selected_accounts.liabilities.sum(:balance), family.currency)
  end

  def assets_money
    return balance_sheet.assets.total_money unless filtered?

    Money.new(selected_accounts.assets.sum(:balance), family.currency)
  end

  def liabilities_money
    return balance_sheet.liabilities.total_money unless filtered?

    Money.new(selected_accounts.liabilities.sum(:balance), family.currency)
  end

  def net_worth_series(period: Period.last_30_days)
    balance_sheet.net_worth_series(period: period)
  end

  def sparkline_points(period: Period.last_30_days)
    net_worth_series(period: period).values.filter_map do |point|
      next unless point.date && point.value

      [ point.date, point.value.amount.to_f ]
    end
  end

  def allocation
    groups = if filtered?
      selected_accounts.group_by { |account| account.accountable_type }.map do |type, accounts|
        amount = accounts.sum { |account| account.classification == "asset" ? account.balance.to_d : -account.balance.to_d }
        Group.new(name: type, total: amount, classification: accounts.first.classification)
      end
    else
      balance_sheet.account_groups
    end
    total = groups.sum { |group| group.total.to_d.abs }
    return [] if total.zero?

    groups.filter_map do |group|
      amount = group.total.to_d
      next if amount.zero?

      Slice.new(
        key: group.name.to_s.parameterize.presence || group.name.to_s,
        label: group.name,
        amount: Money.new(amount, family.currency),
        weight: (amount.abs / total * 100).round(1),
        classification: group.classification
      )
    end.sort_by { |slice| -slice.weight }
  end

  def holdings_allocation
    InvestmentStatement.new(family, user: user).allocation.first(8)
  end

  private
    attr_reader :family, :user, :account_ids

    def filtered?
      account_ids.present?
    end

    def selected_accounts
      @selected_accounts ||= user.finance_accounts.visible.where(id: account_ids)
    end
end
