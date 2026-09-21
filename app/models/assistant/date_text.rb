class Assistant::DateText
  def self.format(date, family: nil)
    return if date.blank?

    value = date.to_date
    iso = value.iso8601
    format_code = family&.date_format.presence
    formatted = format_code.present? ? value.strftime(format_code).strip : iso

    formatted == iso ? iso : "#{formatted} (#{iso})"
  end

  def self.payload(date, family: nil)
    return {} if date.blank?

    {
      date: date.to_date.iso8601,
      date_display: format(date, family: family)
    }
  end
end
