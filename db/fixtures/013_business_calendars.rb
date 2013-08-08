
BusinessCalendar.seed(:account_id) do |s|
  s.account_id = Account.current.id
  s.business_time_data = BusinessCalendar::DEFAULT_SEED_DATA
  s.holiday_data = BusinessCalendar::HOLIDAYS_SEED_DATA
  s.time_zone = Account.current.time_zone
  s.is_default = true
  s.name = "Default"
  s.description = "Default Business Calendar"
end
