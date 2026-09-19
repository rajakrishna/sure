require "test_helper"

class CommandPaletteTest < ActiveSupport::TestCase
  test "includes review inbox and ask destinations" do
    items = CommandPalette.new(user: users(:family_admin)).items

    assert items.any? { |item| item.path == "/ai_proposals" }
    assert items.any? { |item| item.path == "/chats/new" }
    assert items.any? { |item| item.path == "/plan?tab=cash_flow" }
  end
end
