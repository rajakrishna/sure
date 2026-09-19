require "test_helper"

class CategoryExcludeTest < ActiveSupport::TestCase
  test "budget_included omits exclude_from_budget categories" do
    family = families(:dylan_family)
    category = family.categories.create!(name: "Excluded gifts", exclude_from_budget: true, emoji: "🎁")

    assert category.exclude_from_budget?
    assert_equal "🎁 Excluded gifts", category.display_label
    assert_not_includes family.categories.budget_included, category
  end
end
