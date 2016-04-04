# Add workday and weekday concepts to the Date class
class Date
  attr_accessor :business_calendar_config

  def workday?(business_calendar_config=nil)
    business_calendar_config ||= BusinessCalendar.config
    self.weekday? && business_calendar_config.holidays.include?(self)
  end
  
  def weekday?(business_calendar_config=nil)
    #[1,2,3,4,5].include? self.wday
    business_calendar_config ||= BusinessCalendar.config
    business_calendar_config.weekdays.include? self.wday
  end
  
  def business_days_until(to_date)
    (self...to_date).select{ |day| day.workday? }.size
  end
end
