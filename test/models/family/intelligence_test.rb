require "test_helper"

class Family::IntelligenceTest < ActiveSupport::TestCase
  test "review gate stays locked until enough approvals" do
    family = families(:dylan_family)
    family.update!(ai_review_gate_threshold: 10)

    assert_not family.intelligence_unlocked?
    assert_equal Family::BayesCategorizer::CONFIDENCE_THRESHOLD, family.bayes_confidence_threshold
  end

  test "unlocked families lower the confidence threshold" do
    family = families(:dylan_family)
    family.update!(ai_review_gate_threshold: 1)
    family.ai_proposals.create!(
      source: "bayes",
      kind: "categorize",
      status: "approved",
      payload: { "category_id" => family.categories.first.id }
    )

    assert family.intelligence_unlocked?
    assert_equal 0.5, family.bayes_confidence_threshold
  end

  test "high confidence auto-apply stays off by default" do
    family = families(:dylan_family)

    assert_equal false, family.high_confidence_auto_apply?
  end
end
