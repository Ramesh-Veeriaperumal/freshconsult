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
    class DueBy < Wf::FilterContainer
      
      TEXT_DELIMITER = ","
      
      # STATUS_QUERY = "helpdesk_tickets.status in (select status_id from helpdesk_ticket_statuses where (stop_sla_timer is false and deleted is false and account_id = %s))"
      STATUS_QUERY = "helpdesk_ticket_statuses.stop_sla_timer IS FALSE 
                      AND helpdesk_ticket_statuses.deleted IS FALSE 
                      AND helpdesk_ticket_statuses.account_id=%s"
      
      
      def self.operators
        [:due_by_op]
      end
      
      def split_values
        cond_str = ""
        if Account.current.wf_comma_filter_fix_enabled?
          cond_arr = values.collect! { |n| n }
        else
          cond_arr = values[0].split(TEXT_DELIMITER).collect! {|n| n}
        end
        min_value = minimum_required_condition(cond_arr.collect(&:to_i))
        cond_arr.each do |val|
          next if min_value.present? && val.to_i > min_value

          cond_str << " (#{get_due_by_con(val)}) ||"
        end
        cond_str.chomp('||')
     end
     
      def get_due_by_con(val)
        due_by_hash = { TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due] => "#{condition.full_key} <= '#{::Time.zone.now.to_s(:db)}'",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today] => "#{condition.full_key} >= '#{::Time.zone.now.beginning_of_day.to_s(:db)}' and #{condition.full_key} <= '#{::Time.zone.now.end_of_day.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo] => "#{condition.full_key} >= '#{::Time.zone.now.tomorrow.beginning_of_day.to_s(:db)}' and #{condition.full_key} <= '#{::Time.zone.now.tomorrow.end_of_day.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight] => "#{condition.full_key} >= '#{::Time.zone.now.to_s(:db)}' and #{condition.full_key} <= '#{8.hours.from_now.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_four] => "#{condition.full_key} >= '#{::Time.zone.now.to_s(:db)}' and #{condition.full_key} <= '#{4.hours.from_now.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_two] => "#{condition.full_key} >= '#{::Time.zone.now.to_s(:db)}' and #{condition.full_key} <= '#{2.hours.from_now.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_hour] => "#{condition.full_key} >= '#{::Time.zone.now.to_s(:db)}' and #{condition.full_key} <= '#{1.hour.from_now.to_s(:db)}' ",
          TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_half_hour] => "#{condition.full_key} >= '#{::Time.zone.now.to_s(:db)}' and #{condition.full_key} <= '#{30.minutes.from_now.to_s(:db)}' "}

        response_due_conditions = (condition.to_s == :frDueBy) ? (' and ' + fr_due_condition) : ''

        due_by_hash.each_pair{ |option, query_cond| due_by_hash[option] = query_cond + response_due_conditions } if response_due_conditions.present?
          
        due_by_hash[val.to_i]
      end

      def sql_condition
        return [" #{STATUS_QUERY % Account.current.id} and  (#{split_values}) "] 
      end

      def fr_due_condition
        "helpdesk_tickets.source != #{Helpdesk::Source::OUTBOUND_EMAIL} and helpdesk_ticket_states.agent_responded_at IS NULL "
      end

      def minimum_required_condition(conditions)
        (conditions - TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN.slice(:all_due, :due_today, :due_tomo).values).min
      end
    end
  end  
end