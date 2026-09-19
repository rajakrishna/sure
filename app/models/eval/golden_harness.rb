class Eval::GoldenHarness
  DATASET_PATH = Rails.root.join("test/eval/golden_categorize.yml")
  DATASET_NAME = "golden_categorize"

  Report = Data.define(:dataset, :sample_count, :by_difficulty)

  def self.import!
    raise ArgumentError, "Golden dataset missing at #{DATASET_PATH}" unless File.exist?(DATASET_PATH)

    Eval::Dataset.import_from_yaml(DATASET_PATH)
  end

  def self.report
    dataset = import!
    Report.new(
      dataset: dataset,
      sample_count: dataset.sample_count,
      by_difficulty: dataset.statistics[:by_difficulty]
    )
  end
end
