require "test_helper"

class Assistant::Function::CreateRuleTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @category = categories(:food_and_drink)
    @fn = Assistant::Function::CreateRule.new(@user)
  end

  test "creates an inactive name-matching rule" do
    assert_difference "@family.rules.count" do
      result = @fn.call("name" => "Coffee shops", "match_value" => "Starbucks", "category_id" => @category.id)
      assert result[:success]
      rule = @family.rules.find(result[:rule_id])
      assert_equal "Coffee shops", rule.name
      assert_not rule.active
      assert_equal "like", rule.conditions.first.operator
      assert_equal @category.id.to_s, rule.actions.first.value
    end
  end

  test "rejects a category from another family" do
    other = families(:empty).categories.create!(name: "Other")
    result = @fn.call("match_value" => "x", "category_id" => other.id)
    assert_equal false, result[:success]
    assert_equal "invalid_category", result[:error]
  end
end
