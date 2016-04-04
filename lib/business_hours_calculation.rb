module BusinessHoursCalculation
  
  def action_occured_in_bhrs?(action_time, group)
    business_calendar_config = Group.default_business_calendar(group)
    in_bhrs = Time.working_hours?(action_time,business_calendar_config)
  end
  
  def calculate_time_in_bhrs(previous_action_time, action_time, group)
    business_calendar_config = Group.default_business_calendar(group)
    time_in_bhrs = Time.zone.parse(previous_action_time.to_s).
                         business_time_until(Time.zone.parse(action_time.to_s),business_calendar_config)
    
  end 
end