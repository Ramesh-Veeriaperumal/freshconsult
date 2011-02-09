module BusinessTime

  class BusinessHours
    def initialize(hours)
      @hours = hours
    end

    def ago
      Time.zone ? before(Time.zone.now) : before(Time.now)
    end

    def from_now
      Time.zone ?  after(Time.zone.now) : after(Time.now)
    end

    def after(time)
      after_time = Time.roll_forward(time)
      # Step through the hours, skipping over non-business hours
      @hours.times do
        after_time = after_time + 1.hour

        # Ignore hours before opening and after closing
        if (after_time > Time.end_of_workday(after_time))
          after_time = after_time + off_hours
        end

        # Ignore weekends and holidays
        while !Time.workday?(after_time)
          after_time = after_time + 1.day
        end
      end
      after_time
    end

    def before(time)
      before_time = Time.roll_forward(time)
      # Step through the hours, skipping over non-business hours
      @hours.times do
        before_time = before_time - 1.hour

        # Ignore hours before opening and after closing
        if (before_time < Time.beginning_of_workday(before_time))
          before_time = before_time - off_hours
        end

        # Ignore weekends and holidays
        while !Time.workday?(before_time)
          before_time = before_time - 1.day
        end
      end
      before_time
    end

    private

    def off_hours
      return @gap if @gap
      if Time.zone
        gap_end = Time.zone.parse(BusinessCalendar.config.beginning_of_workday)
        gap_begin = (Time.zone.parse(BusinessCalendar.config.end_of_workday)-1.day)
      else
        gap_end = Time.parse(BusinessCalendar.config.beginning_of_workday)
        gap_begin = (Time.parse(BusinessCalendar.config.end_of_workday) - 1.day)
      end
      @gap = gap_end - gap_begin
    end
  end

end
