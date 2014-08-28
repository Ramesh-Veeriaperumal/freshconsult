module BusinessCalendar::Association

  def self.included(base)
    base.extend(ClassMethods)
  end

  def current_business_calendar
    self.business_calendar ? self.business_calendar : self.business_calendar_default
  end

  def business_calendar_default
    key = ::MemcacheKeys::DEFAULT_BUSINESS_CALENDAR % {:account_id => ::Account.current.id}
    MemcacheKeys.fetch(key) do
      ::Account.current.business_calendar.default.first
    end
  end

  module ClassMethods
    def default_business_calendar(caller=nil)
      if caller && caller.account.features?(:multiple_business_hours)
        caller.current_business_calendar
      elsif ::Account.current
        key = ::MemcacheKeys::DEFAULT_BUSINESS_CALENDAR % {:account_id => ::Account.current.id}
        MemcacheKeys.fetch(key) do
          ::Account.current.business_calendar.default.first
        end
      else
        ::BusinessTime::Config
      end
    end
  end
end
