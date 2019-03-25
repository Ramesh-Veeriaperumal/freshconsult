#--
# Copyright (c) 2010 Michael Berkovich, Geni Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

module Wf
  module Containers
    class DateTime < Wf::FilterContainer
      def self.operators
        [:is, :is_not, :is_after, :is_before]
      end

      def validate
        return 'Value must be provided' if value.blank?
      end

      def sql_condition
        fsm_date_time_fields = TicketFilterConstants::FSM_DATE_TIME_FIELDS.collect { |x| x + "_#{Account.current.id}" }
        date_fields_filter = Account.current.custom_date_time_fields_from_cache.select { |x| fsm_date_time_fields.include?(x.name) }.map(&:column_name)
        if operator == :is && date_fields_filter.include?(condition.full_key.split('.')[1])
          return fsm_appointment_date_filter_sql_condition
        end
        return [" #{condition.full_key} = ? ",   time]     if operator == :is
        return [" #{condition.full_key} <> ? ",  time]     if operator == :is_not
        return [" #{condition.full_key} > ? ",   time]     if operator == :is_after
        return [" #{condition.full_key} < ? ",   time]     if operator == :is_before
      end

      def fsm_appointment_date_filter_sql_condition
        agent_time_zone = User.current.time_zone
        date_time_filter_options_hash = TicketFilterConstants::DATE_TIME_FILTER_DEFAULT_OPTIONS_HASH
        if value == date_time_filter_options_hash[:today]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).beginning_of_day, ::Time.now.in_time_zone(agent_time_zone).end_of_day)
        elsif value == date_time_filter_options_hash[:yesterday]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).yesterday.beginning_of_day, ::Time.now.in_time_zone(agent_time_zone).yesterday.end_of_day)
        elsif value == date_time_filter_options_hash[:tomorrow]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).tomorrow.beginning_of_day, ::Time.now.in_time_zone(agent_time_zone).tomorrow.end_of_day)
        elsif value == date_time_filter_options_hash[:week]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).beginning_of_week, ::Time.now.in_time_zone(agent_time_zone).beginning_of_week.advance(days: 7).end_of_day)
        elsif value == date_time_filter_options_hash[:last_week]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).beginning_of_day.ago(7.days), ::Time.now.in_time_zone(agent_time_zone).end_of_day)
        elsif value == date_time_filter_options_hash[:next_week]
          get_sql_condition(::Time.now.in_time_zone(agent_time_zone).beginning_of_day, :: Time.now.in_time_zone(agent_time_zone).next_week.advance(days: 7).end_of_day)
        else
          condition_key = condition.full_key
          begin
            start_date = value.split('-')[0].to_datetime.in_time_zone(agent_time_zone).strftime('%Y-%m-%d')
            end_date = value.split('-')[1].to_datetime.in_time_zone(agent_time_zone).strftime('%Y-%m-%d')
            if start_date.match(TicketFilterConstants::DATE_FIELD_REGEX) && end_date.match(TicketFilterConstants::DATE_FIELD_REGEX)
              return [" (#{condition_key} >= ? and #{condition_key} <= ?) ", start_date, end_date]
            end
          rescue StandardError => e
            Rails.logger.info "Will_filter date_time::: Invalid date time for #{condition.key}"
          end
        end
      end

      def get_sql_condition(time1, time2)
        [" #{condition.full_key} >= '#{time1}' and #{condition.full_key} <= '#{time2}'"]
      end
    end
  end
end
