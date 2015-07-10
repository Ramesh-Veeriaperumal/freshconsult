json.array! @api_business_calendars do |business_calendar|
  json.cache! business_calendar do
    json.(business_calendar, :id, :name, :description)
    json.partial! 'shared/utc_date_format', item: business_calendar
  end
end
