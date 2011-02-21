module BusinessTime
  
  class BusinessMinutes
    def initialize(minutes)
      @minutes = minutes
    end
    
    def from_now
      Time.zone ?  after(Time.zone.now) : after(Time.now)
    end
    
    def after(time)
      d_v = @minutes.divmod 60
      after_time = d_v[1].minutes.since(d_v[0].business_hours.after(time))
      if (after_time > Time.end_of_workday(after_time))
        overflow = (after_time - Time.end_of_workday(after_time))
        after_time = (3600 - overflow).round.seconds.ago(1.business_hour.after after_time)
      end
      
      after_time
    end
  end
end
