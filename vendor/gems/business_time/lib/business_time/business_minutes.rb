module BusinessTime
  
  class BusinessMinutes
    attr_accessor :business_calendar_config
    
    def initialize(minutes)
      @minutes = minutes
    end
    
    def from_now
      Time.zone ?  after(Time.zone.now) : after(Time.now)
    end
    
    def after(time)
      d_v = @minutes.divmod 60
      d_v0_business_hours = d_v[0].business_hours
      d_v0_business_hours.business_calendar_config = business_calendar_config
      after_time = d_v[1].minutes.since(d_v0_business_hours.after(time))
      if (after_time > Time.end_of_workday(after_time,business_calendar_config))
        overflow = (after_time - Time.end_of_workday(after_time,business_calendar_config))
        one_business_hour = 1.business_hour
        one_business_hour.business_calendar_config = business_calendar_config
        after_time = (3600 - overflow).round.seconds.ago(one_business_hour.after after_time)
      end
      
      after_time
    end
  end
end
