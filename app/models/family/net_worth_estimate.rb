class Family::NetWorthEstimate
  Point = Data.define(:date, :amount, :estimated)

  def initialize(family, user:)
    @family = family
    @user = user
  end

  def intra_period
    snapshot = Family::WealthSnapshot.new(family: family, user: user)
    series = snapshot.net_worth_series(period: Period.last_30_days)
    values = Array(series&.values)
    latest = values.reverse.find { |point| point.date && point.value }
    start = values.find { |point| point.date && point.value }
    today = snapshot.net_worth_money

    points = []
    if start
      points << Point.new(date: start.date, amount: start.value, estimated: false)
    end
    points << Point.new(date: Date.current, amount: today, estimated: latest.nil? || latest.date < Date.current)
    points
  end

  private
    attr_reader :family, :user
end
