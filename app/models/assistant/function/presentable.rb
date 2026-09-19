module Assistant::Function::Presentable
  include Rails.application.routes.url_helpers

  def default_url_options
    Rails.application.config.action_controller.default_url_options.presence ||
      Rails.application.config.action_mailer.default_url_options ||
      { only_path: true }
  end

  def with_presentation(result, chart: nil, deep_links: [])
    return result unless result.is_a?(Hash)
    return result if result[:error] || result["error"]

    result = result.merge(deep_links: deep_links) if deep_links.present?
    result = result.merge(chart: chart) if chart.present?
    result
  end

  def deep_link(label, path)
    { label: label, path: path }
  end

  def sparkline_chart(points, aria_label:)
    return nil if points.blank? || points.size < 2

    {
      type: "sparkline",
      aria_label: aria_label,
      points: points.map { |date, value| { date: date.to_date.iso8601, value: value.to_f } }
    }
  end

  def breakdown_chart(points, aria_label:)
    return nil if points.blank?

    {
      type: "breakdown",
      aria_label: aria_label,
      points: points
    }
  end

  def chart_from_ai_series(series, aria_label:)
    return nil unless series.is_a?(Hash)

    values = series[:values] || series["values"]
    return nil unless values.is_a?(Array) && values.size >= 2

    start_date = series[:start_date] || series["start_date"]
    return nil if start_date.blank?

    step = case series[:interval] || series["interval"]
    when "1 day" then 1.day
    when "1 week" then 1.week
    else 1.month
    end

    origin = start_date.to_date
    points = values.each_with_index.map { |value, index| [ origin + (step * index), value ] }
    sparkline_chart(points, aria_label: aria_label)
  end
end
