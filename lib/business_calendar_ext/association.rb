module BusinessCalendarExt::Association

  def self.included(base)
    base.extend(ClassMethods)
  end

  def current_business_calendar
    self.business_calendar ? self.business_calendar : Account.current.default_calendar_from_cache
  end

  module ClassMethods
    def default_business_calendar(caller=nil)
      if caller && ::Account.current.multiple_business_hours_enabled?
        caller.current_business_calendar
      elsif ::Account.current
        Account.current.default_calendar_from_cache
      else
        ::BusinessTime::Config
      end
    end
  end
end
