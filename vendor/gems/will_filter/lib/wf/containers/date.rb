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
    class Date < Wf::FilterContainer
      def self.operators
        [:is]
      end

      def sql_condition
        agent_time_zone = User.current.time_zone
        if operator == :is
          if value == 'today'
            return [" #{condition.full_key} = '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_day.strftime('%Y-%m-%d')}' "]
          elsif value == 'yesterday'
            return [" #{condition.full_key} = '#{::Time.now.in_time_zone(agent_time_zone).yesterday.beginning_of_day.strftime('%Y-%m-%d')}' "]
          elsif value == 'tomorrow'
            return [" #{condition.full_key} = '#{::Time.now.in_time_zone(agent_time_zone).tomorrow.beginning_of_day.strftime('%Y-%m-%d')}' "]
          elsif value == 'week'
            return [" #{condition.full_key} >= '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_week.strftime('%Y-%m-%d')}' and #{condition.full_key} < '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_week.advance(days: 7).strftime('%Y-%m-%d')}' "]
          elsif value == 'last_week'
            return [" #{condition.full_key} >= '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_day.ago(7.days).strftime('%Y-%m-%d')}' and #{condition.full_key} < '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_day.strftime('%Y-%m-%d')}' "]
          elsif value == 'next_week'
            return [" #{condition.full_key} > '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_day.strftime('%Y-%m-%d')}' and #{condition.full_key} <= '#{::Time.now.in_time_zone(agent_time_zone).beginning_of_day.next_week.advance(days: 7).strftime('%Y-%m-%d')}' "]
          else
            condition_key = condition.key
            begin
              start_date = value.split('-')[0].to_date.strftime('%Y-%m-%d')
              end_date = value.split('-')[1].to_date.strftime('%Y-%m-%d')
              if start_date.match(TicketFilterConstants::DATE_FIELD_REGEX) && end_date.match(TicketFilterConstants::DATE_FIELD_REGEX)
                [" (#{condition_key} >= ? and #{condition_key} <= ?) ", start_date, end_date]
              end
            rescue Exception => e
              Rails.logger.info 'Invalid date'
            end
          end
        end
      end
    end
  end
end
