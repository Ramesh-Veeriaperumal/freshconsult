module DateHelper

  def formatted_date(field_value)
    time_format = Account.current.date_type(:short_day_separated)
    (Time.parse(field_value.to_s).utc).strftime(time_format) if field_value
  end
end
