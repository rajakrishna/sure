require "test_helper"

class Family::FinancialHealthTest < ActiveSupport::TestCase
  test "scores between 0 and 100" do
    user = users(:family_admin)
    snapshot = Family::FinancialHealth.new(family: user.family, user: user).snapshot

    assert_includes 0..100, snapshot.score
    assert_equal 5, snapshot.components.size
  end

  test "record persists a score row" do
    user = users(:family_admin)

    assert_difference "FinancialHealthScore.count", 1 do
      Family::FinancialHealth.new(family: user.family, user: user).record!
    end
  end
end
