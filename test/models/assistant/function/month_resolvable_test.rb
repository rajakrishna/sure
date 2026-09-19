require "test_helper"

class Assistant::Function::MonthResolvableTest < ActiveSupport::TestCase
  class Host
    include Assistant::Function::MonthResolvable

    attr_accessor :family

    def parse(raw)
      parse_month(raw)
    end

    def range(raw)
      resolve_month_range(raw)
    end
  end

  setup do
    @host = Host.new
    @host.family = families(:dylan_family)
  end

  test "parses YYYY-MM" do
    assert_equal Date.new(2026, 8, 1), @host.parse("2026-08")
  end

  test "parses MMM-YYYY" do
    assert_equal Date.new(2026, 8, 1), @host.parse("Aug-2026")
  end

  test "parses Month YYYY" do
    assert_equal Date.new(2026, 8, 1), @host.parse("August 2026")
  end

  test "parses Mon YYYY" do
    assert_equal Date.new(2026, 8, 1), @host.parse("Aug 2026")
  end

  test "parses YYYY/MM" do
    assert_equal Date.new(2026, 8, 1), @host.parse("2026/08")
  end

  test "strips surrounding whitespace before parsing" do
    assert_equal Date.new(2026, 8, 1), @host.parse("  August 2026  ")
  end

  test "rejects unknown formats with accepted-format guidance" do
    error = assert_raises(Assistant::Error) { @host.parse("not-a-month") }

    assert_match(/Invalid month: not-a-month/, error.message)
    assert_match(/YYYY-MM/, error.message)
    assert_match(/MMM-YYYY/, error.message)
    assert_match(/Month YYYY/, error.message)
  end

  test "rejects trailing characters" do
    [ "2026-08-01", "2026-08foo", "August 2026 extra", "2026/08/01" ].each do |raw|
      assert_raises(Assistant::Error, "Expected #{raw.inspect} to be rejected") do
        @host.parse(raw)
      end
    end
  end

  test "resolve_month_range honors a custom month start day" do
    @host.family.update!(month_start_day: 15)

    start_date, end_date = @host.range("August 2026")

    assert_equal Date.new(2026, 8, 15), start_date
    assert_equal Date.new(2026, 9, 14), end_date
  end
end
