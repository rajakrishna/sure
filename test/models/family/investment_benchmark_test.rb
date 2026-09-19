require "test_helper"

class Family::InvestmentBenchmarkTest < ActiveSupport::TestCase
  test "returns percent change for the family ticker" do
    family = families(:dylan_family)
    family.update!(investment_benchmark_symbol: "BENCH")
    security = Security.create!(ticker: "BENCH", name: "Benchmark", exchange_operating_mic: "XNAS", country_code: "US")
    period = Period.last_30_days
    security.prices.create!(date: period.start_date, price: 100, currency: "USD")
    security.prices.create!(date: period.end_date, price: 110, currency: "USD")

    benchmark = Family::InvestmentBenchmark.new(family, period: period)

    assert_equal "BENCH", benchmark.symbol
    assert_equal 10.0, benchmark.return_percent
  end

  test "defaults to SPY when the family has no ticker" do
    family = families(:dylan_family)
    family.update!(investment_benchmark_symbol: nil)

    assert_equal "SPY", Family::InvestmentBenchmark.new(family, period: Period.last_30_days).symbol
  end
end
