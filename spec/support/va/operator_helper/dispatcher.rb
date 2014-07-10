module VA
  module OperatorHelper
    module Dispatcher

      def is ticket_value, rule_value
        ticket_value.to_s == rule_value.to_s
      end
      
      def contains ticket_values, rule_value
        ticket_values = ticket_values.is_a?(Array) ? ticket_values : [ticket_values]
        ticket_values.any? do |ticket_value| ticket_value.downcase.include?(rule_value.downcase) end
      end
      
      def starts_with ticket_value, rule_value
        ticket_value.downcase.starts_with?(rule_value.downcase)
      end

      def ends_with ticket_value, rule_value
        ticket_value.downcase.ends_with?(rule_value.downcase)
      end
      
      def selected ticket_value, rule_value
        ticket_value
      end
      
      def greater_than ticket_value, rule_value
        ticket_value > rule_value
      end
      
      def less_than ticket_value, rule_value
        ticket_value < rule_value
      end

      def during ticket_value, rule_value
        send rule_value, ticket_value
      end

      private

        def business_hours(ticket_value)
          Time.working_hours?(ticket_value)
        end

        def non_business_hours(ticket_value)
          !Time.workday?(ticket_value) || !Time.working_hours?(ticket_value)
        end

        def holidays(ticket_value)
          !Time.workday?(ticket_value)
        end

      public #Negative Operators

        def is_not ticket_value, rule_value
          !is ticket_value, rule_value
        end 

        def does_not_contain ticket_value, rule_value
          !contains ticket_value, rule_value
        end

        def not_selected ticket_value, rule_value
          !selected ticket_value, rule_value
        end

    end
  end
end