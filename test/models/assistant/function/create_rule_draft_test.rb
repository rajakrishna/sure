require "test_helper"

class Assistant::Function::CreateRuleDraftTest < ActiveSupport::TestCase
  test "records a proposal without creating a rule" do
    user = users(:family_admin)
    category = user.family.categories.first
    fn = Assistant::Function::CreateRuleDraft.new(user)

    assert_no_difference "Rule.count" do
      result = fn.call("match_value" => "STARBUCKS", "category_id" => category.id)
      assert result[:pending_approval]
    end
  end
end
