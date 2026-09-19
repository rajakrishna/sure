# Shared month handling for assistant tools so month slugs round-trip
# between get_budget, update_budget, get_transactions, and
# get_income_statement, including families with a custom month start day.
module Assistant::Function::MonthResolvable
  ACCEPTED_MONTH_FORMATS = "YYYY-MM, MMM-YYYY, or Month YYYY"

  private
    def resolve_month_start(raw)
      base = parse_month(raw)
      return (base || Date.current).beginning_of_month unless family.uses_custom_month_start?

      # Match Budget.param_to_date for explicit slugs so the input round-trips with the response.
      base ? Date.new(base.year, base.month, family.month_start_day) : family.custom_month_start_for(Date.current)
    end

    def resolve_month_range(raw)
      start_date = resolve_month_start(raw)
      end_date = if family.uses_custom_month_start?
        family.custom_month_end_for(start_date)
      else
        start_date.end_of_month
      end
      [ start_date, end_date ]
    end

    def apply_month_window!(params, month)
      return if month.blank?
      return if params["start_date"].present? && params["end_date"].present?

      start_date, end_date = resolve_month_range(month)
      params["start_date"] = start_date.iso8601 if params["start_date"].blank?
      params["end_date"] = end_date.iso8601 if params["end_date"].blank?
      nil
    rescue Assistant::Error => e
      e.message
    end

    def parse_month(raw)
      return nil if raw.blank?

      value = raw.to_s.strip

      # Date.strptime ignores trailing characters, so guard with strict anchors first.
      fmt = case value
      when /\A\d{4}-\d{2}\z/ then "%Y-%m"
      when /\A[A-Za-z]{3}-\d{4}\z/ then "%b-%Y"
      when /\A[A-Za-z]{3,9}\s+\d{4}\z/ then "%B %Y"
      when /\A\d{4}\/\d{2}\z/ then "%Y/%m"
      end

      raise invalid_month_error(raw) if fmt.nil?

      Date.strptime(value, fmt)
    rescue ArgumentError
      begin
        Date.strptime(value, "%b %Y")
      rescue ArgumentError
        raise invalid_month_error(raw)
      end
    end

    def invalid_month_error(raw)
      Assistant::Error.new("Invalid month: #{raw}. Use #{ACCEPTED_MONTH_FORMATS}.")
    end
end
