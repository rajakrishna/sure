require "test_helper"

class CategoryExcludeTest < ActiveSupport::TestCase
  test "budget_included omits exclude_from_budget categories" do
    family = families(:dylan_family)
    category = family.categories.create!(name: "Excluded gifts", exclude_from_budget: true, emoji: "🎁")

    assert category.exclude_from_budget?
    assert_equal "🎁 Excluded gifts", category.display_label
    assert_not_includes family.categories.budget_included, category
  end

  test "budget_group_name uses the parent when present" do
    family = families(:dylan_family)
    parent = family.categories.create!(name: "Food group")
    child = family.categories.create!(name: "Coffee group", parent: parent)

    assert_equal parent.display_name, child.budget_group_name
    assert_equal parent.display_name, parent.budget_group_name
  end
end
