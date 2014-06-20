module VA::OperatorHelper
  module Supervisor

    def hours_since_is ticket_value, rule_value
      time_diff(ticket_value) == rule_value
    end
    
    def hours_since_less_than ticket_value, rule_value
      diff = time_diff(ticket_value)
      diff < rule_value #&& diff > 0 #Need to uncomment once the bug(dueBy, frDueBy - lessthan operator) is fixed
    end

    def hours_since_greater_than ticket_value, rule_value
      diff = time_diff(ticket_value)
      diff > rule_value
    end

    private

      def time_diff(ticket_value)
        ((Time.now - ticket_value)/3600).floor
      end
      
  end
end