class Family::ForecastExplainer
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You narrate a deterministic household cash forecast.
    Rules:
    - Write 2-3 plain sentences addressed to the user as "you".
    - Use only the provided numbers. Never invent amounts or dates.
    - Repeat monetary amounts exactly as formatted.
    - No product upsell, no emoji, no exclamation marks.
    - Respond with the sentences only.
  PROMPT

  def initialize(family:, user:)
    @family = family
    @user = user
  end

  def build
    hub = PlanHub.new(family: family, user: user)
    projection = {
      "horizon_days" => PlanHub::FORECAST_HORIZON_DAYS,
      "cash_on_hand" => hub.cash_on_hand.amount.to_s,
      "bills_total" => hub.forecast_bills_total.amount.to_s,
      "remainder" => hub.forecast_remainder.amount.to_s,
      "currency" => family.currency,
      "upcoming" => hub.forecast_obligations.sort_by(&:effective_due_on).first(5).map do |occurrence|
        {
          "name" => occurrence.recurring_transaction.display_name,
          "due_on" => occurrence.effective_due_on.iso8601,
          "amount" => occurrence.remaining_amount_money.amount.to_s
        }
      end
    }

    family.forecast_explains.create!(
      horizon_days: PlanHub::FORECAST_HORIZON_DAYS,
      projection: projection,
      narration: narrate(projection, hub),
      generated_at: Time.current
    )
  end

  private
    attr_reader :family, :user

    def narrate(projection, hub)
      llm_narration(projection) || template_narration(hub)
    end

    def template_narration(hub)
      I18n.t(
        "forecast_explains.template",
        cash: hub.cash_on_hand.format,
        bills: hub.forecast_bills_total.format,
        remainder: hub.forecast_remainder.format,
        days: PlanHub::FORECAST_HORIZON_DAYS
      )
    end

    def llm_narration(projection)
      return nil unless provider

      response = provider.chat_response(
        projection.to_json,
        model: provider.class.effective_model,
        instructions: SYSTEM_PROMPT,
        family: family
      )
      return nil unless response.success?

      response.data.messages.filter_map(&:output_text).join(" ").strip.presence
    rescue => e
      DebugLogEntry.capture(
        category: "forecast_explain",
        level: "warn",
        message: "Forecast narration failed: #{e.class}: #{e.message}",
        source: self.class.name,
        family: family
      )
      nil
    end

    def provider
      return @provider if defined?(@provider)
      return @provider = nil unless family.users.any?(&:ai_enabled?)

      @provider = Provider::Registry.preferred_llm_provider
    end
end
