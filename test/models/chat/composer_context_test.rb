require "test_helper"

class Chat::ComposerContextTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
  end

  test "prepends bill context when preview is on" do
    @user.update!(preferences: (@user.preferences || {}).merge("preview_features_enabled" => true))
    series = recurring_transactions(:netflix_subscription)

    merged = Chat::ComposerContext.merge(
      "How is this bill?",
      [ { "type" => "bill", "id" => series.id } ],
      user: @user
    )

    assert_includes merged, "Bill:"
    assert_includes merged, series.display_name
  end

  test "prepends account and transaction context" do
    account = accounts(:depository)
    transaction = transactions(:one)

    merged = Chat::ComposerContext.merge(
      "What happened here?",
      [
        { "type" => "account", "id" => account.id },
        { "type" => "transaction", "id" => transaction.id }
      ],
      user: @user
    )

    assert_includes merged, "Attached context"
    assert_includes merged, account.name
    assert_includes merged, "What happened here?"
    assert_includes merged, Assistant::DateText.format(transaction.entry.date, family: @user.family)
    assert_match(/\d{4}/, merged)
  end

  test "ignores inaccessible accounts" do
    merged = Chat::ComposerContext.merge(
      "Hi",
      [ { "type" => "account", "id" => accounts(:investment).id } ],
      user: users(:family_member)
    )

    assert_equal "Hi", merged
  end

  test "includes a text file excerpt" do
    file = Struct.new(:original_filename, :content_type, :read, keyword_init: true).new(
      original_filename: "note.txt",
      content_type: "text/plain",
      read: "statement line 1"
    )

    merged = Chat::ComposerContext.merge("Look", "[]", user: @user, attachments: [ file ])

    assert_includes merged, "note.txt"
    assert_includes merged, "statement line 1"
    assert_includes merged, "Look"
  end
end
