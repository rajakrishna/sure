require "test_helper"

class Transaction::InboxTest < ActiveSupport::TestCase
  test "counts assigned uncategorized transactions" do
    user = users(:family_admin)
    inbox = Transaction::Inbox.new(family: user.family, user: user)

    assert_kind_of Integer, inbox.assigned_to_user_count
    assert inbox.transactions.to_a
  end
end
