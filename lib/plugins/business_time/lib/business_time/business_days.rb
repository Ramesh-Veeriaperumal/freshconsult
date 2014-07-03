module BusinessTime

  class BusinessDays
    def initialize(days)
      @days = days
    end

    def after(time = Time.zone.now)
      #SignalException (SIGABRT): in business_time calculation becuase of parsing. Pratheepv
      # time = Time.zone ? Time.zone.parse(time.to_s) : Time.parse(time.to_s)
      next_time = Time.roll_forward(time)
      if !Time.workday?(time) || !Time.working_hours?(time)
        number = @days - 1
        started_in_off_hours = true
      else
        number = @days
      end

      number.times do
        begin
          next_time = next_time + 1.day
          while !Time.workday?(next_time)
            next_time = next_time + 1.day
          end
        end
      end

      if !Time.working_hours?(next_time) || started_in_off_hours
        next_time = Time.end_of_workday(next_time)
      end

      next_time
    end

    alias_method :from_now, :after
    alias_method :since, :after
    
    # def before(time = Time.zone.now)
    #   #SignalException (SIGABRT): in business_time calculation becuase of parsing. Pratheepv
    #   # time = Time.zone ? Time.zone.parse(time.to_s) : Time.parse(time.to_s)
    #   next_time = Time.roll_backward(time)
    #   @days.times do
    #     begin
    #       next_time = Time.roll_backward(next_time-1.day)
    #       time = time - 1.day
    #       format = "%B %d %Y #{time.to_s.split(" ")[1]}"
    #       business_time  = Time.zone ? Time.zone.parse(next_time.strftime(format)) :
    #       Time.parse(next_time.strftime(format))
    #       if (Time.before_business_hours?(business_time) || Time.after_business_hours?(business_time))
    #         next_time = Time.get_previous_working_day(business_time)
    #       else
    #         next_time = business_time
    #       end
    #     end
    #   end
    #   next_time
    # end

    
    # alias_method :ago, :before
    # alias_method :until, :before

  end    
end
