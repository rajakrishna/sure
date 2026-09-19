require "test_helper"

class Family::WeeklyBriefingBuilderTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "returns a headline, items, prompts, and memory" do
    payload = Family::WeeklyBriefingBuilder.new(@family).build

    assert payload["headline"].present?
    assert payload["items"].is_a?(Array)
    assert payload["suggested_prompts"].is_a?(Array)
    assert payload["memory"].present?
    assert payload["suggested_prompts"].any?
  end
end
