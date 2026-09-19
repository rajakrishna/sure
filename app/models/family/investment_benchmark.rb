class Family::InvestmentBenchmark
  DEFAULT_SYMBOL = "SPY"

  def initialize(family, period:)
    @family = family
    @period = period
  end

  def symbol
    family.investment_benchmark_symbol.presence || DEFAULT_SYMBOL
  end

  def return_percent
    security = Security.find_by("UPPER(ticker) = ?", symbol.upcase)
    return nil unless security

    prices = security.prices.where(date: period.start_date..period.end_date).order(:date)
    first = prices.first
    last = prices.last
    return nil unless first && last && first.price.to_d.positive?

    ((last.price.to_d - first.price.to_d) / first.price.to_d * 100).round(2)
  rescue StandardError
    nil
  end

  private
    attr_reader :family, :period
end
