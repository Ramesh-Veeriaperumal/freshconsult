# Add workday and weekday concepts to the Time class
class Time
  class << self
    # Gives the time at the end of the workday, assuming that this time falls on a
    # workday.
    # Note: It pretends that this day is a workday whether or not it really is a
    # workday.

    def end_of_workday(day)
      time = workday?(day) ? BusinessCalendar.config.end_of_workday(day.wday) : "0:00:00"
      time_with_format(time, day)
      
    end

    # Gives the time at the beginning of the workday, assuming that this time
    # falls on a workday.
    # Note: It pretends that this day is a workday whether or not it really is a
    # workday.
    def beginning_of_workday(day)
      time = workday?(day) ? BusinessCalendar.config.beginning_of_workday(day.wday) : "0:00:00"
      time_with_format(time, day)
    end

    # True if this time is on a workday (between 00:00:00 and 23:59:59), even if
    # this time falls outside of normal business hours.
    def workday?(day)
      Time.weekday?(day) &&
          !BusinessCalendar.config.holidays.include?(day.to_date)
    end

    # True if this time falls on a weekday.
    def weekday?(day)
      # TODO AS: Internationalize this!
      #[1,2,3,4,5].include? day.wday
      BusinessCalendar.config.weekdays.include? day.wday
    end

    def before_business_hours?(time)
      time < beginning_of_workday(time)
    end

    def after_business_hours?(time)
      time > end_of_workday(time)
    end

    def working_hours?(time)
      (time >= beginning_of_workday(time)) and (time <= end_of_workday(time))
    end

    # Rolls forward to the next beginning_of_workday
    # when the time is outside of business hours
    def roll_forward(time)
      if (Time.before_business_hours?(time) || !Time.workday?(time))
        next_business_time = Time.beginning_of_workday(time)
      elsif Time.after_business_hours?(time)
        next_business_time = Time.beginning_of_workday(time + 1.day)
      else
        next_business_time = time.clone
      end

      while !Time.workday?(next_business_time)
        next_business_time = Time.beginning_of_workday(next_business_time + 1.day)
      end
      
      next_business_time
    end

    def roll_backward(time)
      if Time.after_business_hours?(time) || !Time.workday?(time)
        previous_business_time = Time.end_of_workday(time)
      elsif Time.before_business_hours?(time)
         previous_business_time = Time.end_of_workday(time-1.day)
      else
        previous_business_time = time.clone
      end

      while !Time.workday?(previous_business_time)
        previous_business_time = Time.end_of_workday(previous_business_time - 1.day)
      end

      previous_business_time
    end

    private

     def time_with_format(time, day)
      format = "%B %d %Y #{time}"
        Time.zone ? Time.zone.parse(day.strftime(format)) :
          Time.parse(day.strftime(format))
     end
  end
end


class Time

  def business_time_until(to_time)

    # Make sure that we will calculate time from A to B "clockwise"
    direction = 1
    if self < to_time
      time_a = self
      time_b = to_time
    else
      time_a = to_time
      time_b = self
      direction = -1
    end

    # Align both times to the closest business hours
    time_a = Time::roll_forward(time_a)
    time_b = Time::roll_forward(time_b)

    # If same date, then calculate difference straight forward
    if time_a.to_date == time_b.to_date
      result = time_b - time_a
      return result *= direction
    end
    
 
    # Both times are in different dates

    result = Time::parse(time_a.strftime('%Y-%m-%d ') + 
        BusinessCalendar.config.end_of_workday(time_a.wday)) - time_a   # First day
    result += time_b - Time::parse(time_b.strftime('%Y-%m-%d  ') + 
        BusinessCalendar.config.beginning_of_workday(time_b.wday)) # Last day

    time_b = Time.end_of_workday(Time.roll_backward(time_b-1.day)) #To preceed the time_b since last day is calculated - Abhinav
    # # All days in between
    while(time_b.to_date > time_a.to_date)
      time_a = Time::roll_forward(time_a+1.day)
      duration_of_working_day = Time::end_of_workday(time_a) - Time::beginning_of_workday(time_a)
      result += duration_of_working_day  
    end
    
    
    
    # Make sure that sign is correct
    result *= direction
  end

end