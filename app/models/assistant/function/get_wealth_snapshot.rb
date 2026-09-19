class Assistant::Function::GetWealthSnapshot < Assistant::Function
  class << self
    def name
      "get_wealth_snapshot"
    end

    def description
      "Returns net worth, a 30-day sparkline, and allocation by account type."
    end
  end

  def call(_params = {})
    snapshot = Family::WealthSnapshot.new(family: family, user: user)
    {
      net_worth: snapshot.net_worth_money.format,
      assets: snapshot.assets_money.format,
      liabilities: snapshot.liabilities_money.format,
      allocation: snapshot.allocation.map { |slice| { label: slice.label, weight: slice.weight, amount: slice.amount.format, classification: slice.classification } }
    }
  end
end
