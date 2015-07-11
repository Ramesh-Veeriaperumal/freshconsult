json.cache! @api_business_calendar do
  json.(@api_business_calendar, :id, :name, :description, :time_zone)
  json.partial! 'shared/boolean_format', boolean_fields: { is_default: @api_business_calendar.is_default }
  json.partial! 'shared/utc_date_format', item: @api_business_calendar
end
