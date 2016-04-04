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
    class TextDelimited < Wf::FilterContainer

      TEXT_DELIMITER = ","

      def self.operators
        [:is_in]
      end

      def template_name
        'text'
      end

      def validate
        #return "Values must be provided. Separate values with '#{TEXT_DELIMITER}'" if value.blank?
      end

      def split_values
        value.split(TEXT_DELIMITER)
      end
      
      # -1 represents unassigned 
      def handle_unassigned
        array_values = split_values
        array_values.delete("-1")
        
        return [" (#{condition.full_key} is NULL) "] if array_values.empty?
        return [" (#{condition.full_key} is NULL or #{condition.full_key} in (?)) ",array_values]
      end

      def sql_condition
        return [" #{condition.full_key} is NULL "] if value.empty?
        return handle_unassigned if value.include?("-1")
        return [" #{condition.full_key} in (?) ", split_values] if operator == :is_in 
      end
    end
  end
end
