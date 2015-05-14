module Wf
  module Containers
    class Time < Wf::FilterContainer

      delegate :table_name, :to => :filter

      def self.operators
        [ :is_greater_than ]
      end

      def validate
        return "Value must be provided" if value.blank?
        return "Value must be a valid date/time (2008-01-01 14:30:00)" if time == nil
      end

      def time
        begin
          ::Time.zone.now.ago(value.to_i.minutes).to_s(:db)
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          nil
        end
      end

      def time_at(ti,type)
        return (type == "start_date" ? "#{::Time.zone.parse(ti).to_s(:db)}" : "#{::Time.zone.parse(ti).end_of_day.to_s(:db)}")
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        nil
      end

      def sql_condition
        case value
          when "today" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_day.to_s(:db)}' "]
          when "yesterday" then
            return [%( #{table_name}.created_at > '#{::Time.zone.now.yesterday.beginning_of_day.to_s(:db)}' and
              #{table_name}.created_at < '#{::Time.zone.now.beginning_of_day.to_s(:db)}' )]
          when "week" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_week.to_s(:db)}' "]
          when "last_week" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_day.ago(7.days).to_s(:db)}' "]
          when "month" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_month.to_s(:db)}' "]
          when "last_month" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_day.ago(1.month).to_s(:db)}' "]
          when "two_months" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_day.ago(2.months).to_s(:db)}' "]
          when "six_months" then
            return [" #{table_name}.created_at > '#{::Time.zone.now.beginning_of_day.ago(6.months).to_s(:db)}' "]
          else
            if is_numeric?(value)
              return [" #{table_name}.created_at > ? ", time]
            else
              condition_key = condition.key
              condition_key = "#{table_name}.#{condition_key}" if condition_key.eql?(:created_at)
              start_date, end_date = value.split("-")
              [" (#{condition_key} >= ? and #{condition_key} <= ?) ", time_at(start_date,"start_date"), time_at(end_date,"end_date")] 
            end
        end 
      end
    end
  end
end
