require "test_helper"

class CommandPaletteTest < ActiveSupport::TestCase
  test "includes review inbox and ask destinations" do
    items = CommandPalette.new(user: users(:family_admin)).items

    assert items.any? { |item| item.path == "/ai_proposals" }
    assert items.any? { |item| item.path == "/chats/new" }
    assert items.any? { |item| item.path == "/plan?tab=cash_flow" }
    assert items.any? { |item| item.path == "/plan?tab=bills" }
    assert items.any? { |item| item.path == "/settings/profile" }
    assert_not items.any? { |item| item.path == "/transactions/inbox" }
    assert_not items.any? { |item| item.path == "/recurring_transactions/board" }
  end

  test "ask item opens the rail and submits" do
    ask = CommandPalette.new(user: users(:family_admin)).items.find { |item| item.path == "/chats/new" }

    assert_equal :sidebar_chat, ask.frame
    assert_includes ask.data[:action].to_s, "ask-link#open"
  end

  test "includes action shortcuts not just jumps" do
    items = CommandPalette.new(user: users(:family_admin)).items
    paths = items.map(&:path)

    assert_includes paths, "/ai_proposals"
    assert paths.any? { |path| path.include?("q[types][]=expense") }
  end
end
