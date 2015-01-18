class Va::Handlers::DateTime < Va::RuleHandler
  def filter_query_is
    [ "round((unix_timestamp(UTC_TIMESTAMP()) - unix_timestamp(#{condition.db_column}))/3600) = ?",
      value.to_i ]
  end
  
  def filter_query_less_than
    [ "#{condition.db_column} > ?", value.to_i.hours.ago.to_s(:db) ]
  end
  
  def filter_query_greater_than
    [ "#{condition.db_column} < ?", value.to_i.hours.ago.to_s(:db) ]
  end

  private
      def during(evaluated_on_value) #possible values are business_hours, non_business_hours & holidays
        send(value, evaluated_on_value)
      end

      def business_hours(evaluated_on_value)
        Time.working_hours?(evaluated_on_value, fetch_business_hours)
      end

      def non_business_hours(evaluated_on_value)
        !Time.workday?(evaluated_on_value,fetch_business_hours) || !Time.working_hours?(evaluated_on_value,fetch_business_hours)
      end

      def holidays(evaluated_on_value)
        !Time.workday?(evaluated_on_value,fetch_business_hours)
      end

      def fetch_business_hours
        if Account.current.features_included?(:multiple_business_hours) and sub_value
          Account.current.business_calendar.find_by_id(sub_value)
        end
      end
end
