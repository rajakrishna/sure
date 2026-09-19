require "test_helper"

class Family::NetWorthEstimateTest < ActiveSupport::TestCase
  test "returns start and today points" do
    points = Family::NetWorthEstimate.new(families(:dylan_family), user: users(:family_admin)).intra_period

    assert points.any?
    assert_equal Date.current, points.last.date
    assert points.last.amount
  end
end
