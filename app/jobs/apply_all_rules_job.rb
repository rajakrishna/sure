class ApplyAllRulesJob < ApplicationJob
  queue_as :medium_priority

  def perform(family, execution_type: "manual")
    family.rules.by_priority.each do |rule|
      RuleJob.perform_now(rule, ignore_attribute_locks: true, execution_type: execution_type)
    end
  end
end
