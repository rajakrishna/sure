class Assistant::Function::GetFinancialHealth < Assistant::Function
  class << self
    def name
      "get_financial_health"
    end

    def description
      "Returns a 0-100 local financial health score with component breakdown and suggested actions. No upsell."
    end
  end

  def call(_params = {})
    snapshot = Family::FinancialHealth.new(family: family, user: user).snapshot
    {
      score: snapshot.score,
      components: snapshot.components_as_json,
      actions: snapshot.actions
    }
  end
end
