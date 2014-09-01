module BusinessTime

  class BusinessHours
    attr_accessor :business_calendar_config
    
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
      after_time = Time.roll_forward(time,business_calendar_config)
      # Step through the hours, skipping over non-business hours
      @hours.times do
        after_time = after_time + 1.hour

        # Ignore hours before opening and after closing
        if(after_time > Time.end_of_workday(after_time - 1.hour,business_calendar_config)) #Subracting 1 hr to satisfy the edge cases - Abhinav
          after_time = after_time + off_hours_till_next_day(after_time)
        end

        # Ignore weekends and holidays
        while !Time.workday?(after_time,business_calendar_config)
          after_time = Time.beginning_of_workday(after_time + 1.day,business_calendar_config)
        end
      end

      after_time
    end

    def before(time)
      before_time = Time.roll_backward(time,business_calendar_config)
      # Step through the hours, skipping over non-business hours
      @hours.times do
        before_time = before_time - 1.hour

        # Ignore hours before opening and after closing
        if(before_time < Time.beginning_of_workday(before_time + 1.hour,business_calendar_config)) #Adding 1 hr to satisfy the edge cases - Abhinav
          before_time = before_time - off_hours_from_previous_day(before_time)
        end

        # Ignore weekends and holidays
        while !Time.workday?(before_time,business_calendar_config)
          before_time =  Time.beginning_of_workday(before_time - 1.day,business_calendar_config)
        end
      end

      before_time
    end

    private
    
      def off_hours_till_next_day(time)  
        gap_begin =  Time.end_of_workday(time - 1.hour,business_calendar_config)
        gap_end = Time.beginning_of_workday(Time.roll_forward(time,business_calendar_config),business_calendar_config)
        gap_end - gap_begin
      end

      def off_hours_from_previous_day(time)
        gap_end =  Time.beginning_of_workday(time + 1.hour,business_calendar_config)
        gap_begin = Time.end_of_workday(Time.roll_backward(time,business_calendar_config),business_calendar_config)
        gap_end - gap_begin
      end
    
  end
end
