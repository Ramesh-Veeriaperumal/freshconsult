class TimeSheetDecorator < SimpleDelegator
  class << self
    def format_time_spent(time_spent)
      if time_spent.is_a? Numeric
        # converts seconds to hh:mm format say 120 seconds to 00:02
        hours, minutes = time_spent.divmod(60).first.divmod(60)
        #  formatting 9 to be displayed as 09
        format('%02d:%02d', hours, minutes)
      end
    end
  end
end