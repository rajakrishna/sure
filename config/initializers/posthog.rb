require "posthog"

Rails.configuration.x.posthog = ActiveSupport::OrderedOptions.new
Rails.configuration.x.posthog.development_enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("POSTHOG_DEVELOPMENT_ENABLED", "false"))
Rails.configuration.x.posthog.api_key = ENV["POSTHOG_KEY"].presence
Rails.configuration.x.posthog.host = ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
Rails.configuration.x.posthog.feedback_enabled = ENV["POSTHOG_KEY"].present? &&
  ActiveModel::Type::Boolean.new.cast(ENV.fetch("POSTHOG_FEEDBACK_ENABLED", "false"))
Rails.configuration.x.posthog.self_hosted_feedback_project = {
  api_key: ENV["POSTHOG_KEY"].presence,
  host: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
}.freeze
Rails.configuration.x.posthog.feedback_surveys = {}.freeze

if (api_key = Rails.configuration.x.posthog.api_key).present?
  $posthog = PostHog::Client.new({
    api_key: api_key,
    host: Rails.configuration.x.posthog.host,
    on_error: Proc.new { |status, msg| puts "PostHog error: #{status} - #{msg}" }
  })
end
