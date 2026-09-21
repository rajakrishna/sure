require "test_helper"

class Assistant::DateTextTest < ActiveSupport::TestCase
  test "formats a date with the family format and ISO" do
    family = families(:dylan_family)
    family.update!(date_format: "%m/%d/%Y")

    assert_equal "09/17/2026 (2026-09-17)", Assistant::DateText.format(Date.new(2026, 9, 17), family: family)
  end

  test "falls back to ISO when no family format is set" do
    assert_equal "2026-09-17", Assistant::DateText.format(Date.new(2026, 9, 17), family: nil)
  end

  test "payload includes ISO date and display text" do
    family = families(:dylan_family)
    family.update!(date_format: "%m/%d/%Y")
    payload = Assistant::DateText.payload(Date.new(2026, 9, 17), family: family)

    assert_equal "2026-09-17", payload[:date]
    assert_equal "09/17/2026 (2026-09-17)", payload[:date_display]
    assert_no_match(/9\/17\/206\b/, payload[:date_display])
  end
end
