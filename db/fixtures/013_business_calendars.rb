
BusinessCalendar.seed(:account_id) do |s|
  s.account_id = Account.current.id
  s.business_time_data = BusinessCalendar::DEFAULT_SEED_DATA
  s.holiday_data = BusinessCalendar::HOLIDAYS_SEED_DATA
end
