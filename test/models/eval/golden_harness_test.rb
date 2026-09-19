require "test_helper"

class Eval::GoldenHarnessTest < ActiveSupport::TestCase
  test "imports the golden categorize dataset" do
    report = Eval::GoldenHarness.report

    assert_equal "golden_categorize", report.dataset.name
    assert_operator report.sample_count, :>, 0
    assert report.by_difficulty.present?
  end
end
