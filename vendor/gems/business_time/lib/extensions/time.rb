# Add workday and weekday concepts to the Time class
class Time
    # Gives the time at the end of the workday, assuming that this time falls on a
    # workday.
    # Note: It pretends that this day is a workday whether or not it really is a
    # workday.

  def self.end_of_workday(day, business_calendar_config = nil)
    business_calendar_config ||= BusinessCalendar.config
    time = workday?(day, business_calendar_config) ? business_calendar_config.end_of_workday(day.wday) : '0:00:00'
    business_calendar_config.beginning_of_day_in_date_time(day, time)
  end

  # Gives the time at the beginning of the workday, assuming that this time
  # falls on a workday.
  # Note: It pretends that this day is a workday whether or not it really is a
  # workday.
  def self.beginning_of_workday(day, business_calendar_config = nil)
    business_calendar_config ||= BusinessCalendar.config
    time = workday?(day, business_calendar_config) ? business_calendar_config.beginning_of_workday(day.wday) : '0:00:00'
    business_calendar_config.end_of_day_in_date_time(day, time)
  end

  # True if this time is on a workday (between 00:00:00 and 23:59:59), even if
  # this time falls outside of normal business hours.
  def self.workday?(day, business_calendar_config = nil)
    business_calendar_config ||= BusinessCalendar.config
    weekday?(day, business_calendar_config) && !holiday?(day, business_calendar_config)
  end

  def self.holiday?(day, business_calendar_config = nil)
    business_calendar_config ||= BusinessCalendar.config
    business_calendar_config.holiday_set.include?("#{day.day} #{day.mon}")
  end

  # True if this time falls on a weekday.
  def self.weekday?(day, business_calendar_config = nil)
    # TODO: AS: Internationalize this!
    # [1,2,3,4,5].include? day.wday
    business_calendar_config ||= BusinessCalendar.config
    business_calendar_config.weekday_set.include? day.wday
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
end

class Time
  def business_time_until(to_time, business_calendar_config = nil)
    business_calendar_config ||= BusinessCalendar.config
    from_time = Time.zone.parse(strftime('%Y-%m-%d %H:%M:%S'))
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
    time_a = Time.roll_forward(time_a, business_calendar_config)
    time_b = Time.roll_forward(time_b, business_calendar_config)

    # For same day, simple difference is the answer.
    if time_a.to_date == time_b.to_date
      time_b - time_a
    else
      # Both times are on different dates. Duration may be shorter than a day.
      first_day_duration = Time.zone.parse(time_a.strftime('%Y-%m-%d ') +
                                   business_calendar_config.end_of_workday(time_a.wday)) - time_a
      last_day_duration = time_b - Time.zone.parse(time_b.strftime('%Y-%m-%d  ') +
                                             business_calendar_config.beginning_of_workday(time_b.wday))

      # Remaining are full days.
      date_a = time_a.to_date + 1
      date_b = time_b.to_date - 1
      days = (date_b - date_a).to_i
      wday_counts = [days / 7] * 7
      (0..(days % 7)).each { |day| wday_counts[(date_a.wday + day) % 7] += 1 }
      begin
        (date_a.year..date_b.year).each do |year|
          business_calendar_config.holidays.each do |holiday|
            holidate = Date.parse("#{holiday.day}-#{holiday.mon}-#{year}")
            if (holidate >= date_a) && (holidate <= date_b) && (wday_counts[holidate.wday] > 0)
              wday_counts[holidate.wday] -= 1
            end
          end
        end
      rescue StandardError => e
        Rails.logger.error "Business Hours : #{business_calendar_config.try(:account_id)} : Error while trying to subtract holidays #{e.inspect} #{e.backtrace.join("\n\t")}"
      end

      wday_duration = [0] * 7
      business_calendar_config.weekdays.each do |wday|
        begin
          wday_duration[wday] = Time.zone.parse(business_calendar_config.end_of_workday(wday)) - Time.zone.parse(business_calendar_config.beginning_of_workday(wday))
        rescue StandardError => e
          Rails.logger.error "Business Hours : #{business_calendar_config.try(:account_id)} : Error while trying to compute working hours #{e.inspect} #{e.backtrace.join("\n\t")}"
        end
      end
      # Add dot product of the two arrays. https://stackoverflow.com/a/7372688/443682
      work_duration_in_between = (0...wday_counts.count).inject(0) { |coeff, wday| coeff + wday_counts[wday] * wday_duration[wday] }
      first_day_duration + work_duration_in_between + last_day_duration
    end * direction
  end
end
