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
    class SpecialResponder < Wf::FilterContainer
      # 1. Any agent condition with array of values -> primary agent in values or internal agent in values
      # 2. Any group condition with array of values -> primary group in values or internal group in values
      # 3. Any agent condition with {:agent => values, :group => values} -> 
      #     (primary agent in values OR internal agent in values OR (primary agent is null AND primary group in values)
      #      OR (internal agent is null AND internal group in values))

      TEXT_DELIMITER = ","

        ANY_COLUMNS = {
          :any_group_id => ["helpdesk_tickets.group_id", "helpdesk_schema_less_tickets.long_tc03"],
          :any_agent_id => ["helpdesk_tickets.responder_id", "helpdesk_schema_less_tickets.long_tc04"]
        }


      def self.operators
        [:is_in]
      end

      def template_name
        'text'
      end

      def validate
        #return "Values must be provided. Separate values with '#{TEXT_DELIMITER}'" if value.blank?
      end

      def value
        values.is_a?(Hash) ? values.values[0] : values.first
      end

      def split_values(val = value)
        val.split(TEXT_DELIMITER)
      end

      def any_query_with_null(keys, values)
        conditions = []
        agent_values = split_values(values[:agent][0])
        agent_values.delete("-1")
        group_values = split_values(values[:group][0])
        if agent_values.present?
          keys.each { |k|
            conditions = generate_query(k, agent_values, conditions)
          }
        end
        [0,1].each {|index|
          group_condition     = generate_query(ANY_COLUMNS[:any_group_id][index], group_values, [])
          agent_condition     = generate_query(ANY_COLUMNS[:any_agent_id][index], ["-1"], [])
          combined_condition  = concat_sql_condition(group_condition, agent_condition[0], nil, "AND", true)
          conditions          = concat_sql_condition(conditions, combined_condition[0], combined_condition[1])
        }
        conditions[0] = "(#{conditions[0]})"
        conditions
      end

      def any_query_without_null(keys, values)
        conditions = []
        keys.each {|k|
          conditions = generate_query(k, values, conditions)
        }
        conditions[0] = "(#{conditions[0]})"
        conditions
      end

      def generate_query(key, values, conditions = [], operator = "OR")
        values = values.clone
        null_exist = values.include?("-1")
        values.delete("-1")
        if values.present?
          in_cond = generate_in_query(key) if values.present?
          conditions = concat_sql_condition(conditions, in_cond, values)
        end
        if null_exist
          null_cond = generate_null_query(key)
          conditions = concat_sql_condition(conditions, null_cond)
        end
        conditions
      end

      def concat_sql_condition(conditions_array, new_condition, new_values = nil, operator = "OR", parenthesis = false)
        conditions_array[0] = (conditions_array.blank? ? new_condition : conditions_array[0]+" #{operator} #{new_condition}")
        conditions_array[0] = "(#{conditions_array[0]})" if parenthesis
        conditions_array << new_values if new_values.present?
        conditions_array
      end

      def generate_in_query(key)
        " #{key} in (?) "
      end

      # -1 represents unassigned 
      def generate_null_query(key)
        " #{key} is NULL "
      end

      def sql_condition
        return nil unless operator == :is_in 
        if condition.key == :any_group_id
          conditions = any_query_without_null(ANY_COLUMNS[condition.key], split_values)
        else
          conditions = values.is_a?(Hash) ? 
              any_query_with_null(ANY_COLUMNS[condition.key], values) :
              any_query_without_null(ANY_COLUMNS[condition.key], split_values)
        end
      end

    end
  end
end
