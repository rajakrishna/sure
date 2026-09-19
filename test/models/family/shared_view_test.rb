require "test_helper"

class Family::SharedViewTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
  end

  test "defaults to ours" do
    view = Family::SharedView.new(family: @family, user: @user, key: nil)

    assert view.ours?
    assert_equal "ours", view.key
  end

  test "scopes member views to owned accounts" do
    member = users(:family_member)
    owned = @family.accounts.visible.where(owner_id: member.id).pluck(:id)
    view = Family::SharedView.new(family: @family, user: @user, key: "member:#{member.id}")

    assert_equal owned.sort, view.account_ids.sort
  end
end
