require "test_helper"

class Family::WealthSnapshotTest < ActiveSupport::TestCase
  test "returns net worth money for the current user" do
    user = users(:family_admin)
    snapshot = Family::WealthSnapshot.new(family: user.family, user: user)

    assert snapshot.net_worth_money.present?
    assert snapshot.allocation.is_a?(Array)
    assert snapshot.sparkline_series.is_a?(Array)
  end
end
