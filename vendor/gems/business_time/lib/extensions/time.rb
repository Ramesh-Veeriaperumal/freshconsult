# Add workday and weekday concepts to the Time class
class Time
    # Gives the time at the end of the workday, assuming that this time falls on a
    # workday.
    # Note: It pretends that this day is a workday whether or not it really is a
    # workday.

    def self.end_of_workday(day,business_calendar_config = nil)
      business_calendar_config ||= BusinessCalendar.config
      time = workday?(day,business_calendar_config) ? business_calendar_config.end_of_workday(day.wday) : "0:00:00"
      time_with_format(time, day)
    end

    # Gives the time at the beginning of the workday, assuming that this time
    # falls on a workday.
    # Note: It pretends that this day is a workday whether or not it really is a
    # workday.
    def self.beginning_of_workday(day,business_calendar_config = nil)
      business_calendar_config ||= BusinessCalendar.config
      time = workday?(day,business_calendar_config) ? business_calendar_config.beginning_of_workday(day.wday) : "0:00:00"
      time_with_format(time, day)
    end

    # True if this time is on a workday (between 00:00:00 and 23:59:59), even if
    # this time falls outside of normal business hours.
    def self.workday?(day,business_calendar_config = nil)
      business_calendar_config ||= BusinessCalendar.config
      Time.weekday?(day,business_calendar_config) &&
          !business_calendar_config.holidays.any?{|h| h.strftime("%d %m") == day.to_date.strftime("%d %m") }
    end

    # True if this time falls on a weekday.
    def self.weekday?(day,business_calendar_config = nil)
      # TODO AS: Internationalize this!
      #[1,2,3,4,5].include? day.wday
      business_calendar_config ||= BusinessCalendar.config
      business_calendar_config.weekdays.include? day.wday
    end

    def self.before_business_hours?(time,business_calendar_config = nil)
      time < beginning_of_workday(time,business_calendar_config)
    end

    def self.after_business_hours?(time,business_calendar_config = nil)
      time > end_of_workday(time,business_calendar_config)
    end

    def self.working_hours?(time,business_calendar_config = nil)
      (time >= beginning_of_workday(time,business_calendar_config)) and (time <= end_of_workday(time,business_calendar_config))
    end

    # Rolls forward to the next beginning_of_workday
    # when the time is outside of business hours
    def self.roll_forward(time,business_calendar_config = nil)
      if (Time.before_business_hours?(time,business_calendar_config) || !Time.workday?(time,business_calendar_config))
        next_business_time = Time.beginning_of_workday(time,business_calendar_config)
      elsif Time.after_business_hours?(time,business_calendar_config)
        next_business_time = Time.beginning_of_workday(time + 1.day,business_calendar_config)
      else
        next_business_time = time.clone
      end

      while !Time.workday?(next_business_time,business_calendar_config)
        next_business_time = Time.beginning_of_workday(next_business_time + 1.day,business_calendar_config)
      end

      next_business_time
    end

    def self.roll_backward(time, business_calendar_config = nil)
      if Time.after_business_hours?(time,business_calendar_config) || !Time.workday?(time,business_calendar_config)
        previous_business_time = Time.end_of_workday(time,business_calendar_config)
      elsif Time.before_business_hours?(time,business_calendar_config)
         previous_business_time = Time.end_of_workday(time-1.day,business_calendar_config)
      else
        previous_business_time = time.clone
      end

      while !Time.workday?(previous_business_time,business_calendar_config)
        previous_business_time = Time.end_of_workday(previous_business_time - 1.day,business_calendar_config)
      end

      previous_business_time
    end

    private

     def self.time_with_format(time, day)
      format = "%B %d %Y #{time}"
        Time.zone ? Time.zone.parse(day.strftime(format)) :
          Time.parse(day.strftime(format))
     end
end


class Time

  def business_time_until(to_time,business_calendar_config=nil)
    business_calendar_config ||= BusinessCalendar.config
    # Make sure that we will calculate time from A to B "clockwise"
    from_time = Time.zone.parse(self.strftime('%Y-%m-%d %H:%M:%S'))
    direction = 1
    if from_time < to_time
      time_a = from_time
      time_b = to_time
    else
      time_a = to_time
      time_b = from_time
      direction = -1
    end

    # Align both times to the closest business hours
    time_a = Time::roll_forward(time_a,business_calendar_config)
    time_b = Time::roll_forward(time_b,business_calendar_config)

    # If same date, then calculate difference straight forward
    if time_a.to_date == time_b.to_date
      result = time_b - time_a
      return result *= direction
    end
    
 
    # Both times are in different dates
    result = Time.zone.parse(time_a.strftime('%Y-%m-%d ') + 
        business_calendar_config.end_of_workday(time_a.wday)) - time_a   # First day
    result += time_b - Time.zone.parse(time_b.strftime('%Y-%m-%d  ') + 
        business_calendar_config.beginning_of_workday(time_b.wday)) # Last day

    time_b = Time.end_of_workday(Time.roll_backward(time_b-1.day,business_calendar_config),business_calendar_config) #To preceed the time_b since last day is calculated - Abhinav
    # # All days in between - Abhinav
    while(time_b.to_date > time_a.to_date)
      time_a = Time::roll_forward(time_a+1.day,business_calendar_config)
      duration_of_working_day = Time::end_of_workday(time_a,business_calendar_config) - Time::beginning_of_workday(time_a,business_calendar_config)
      result += duration_of_working_day  
    end
    
    
    
    # Make sure that sign is correct
    result *= direction
  end

end