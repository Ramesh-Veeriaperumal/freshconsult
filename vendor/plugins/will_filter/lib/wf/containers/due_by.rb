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

class Wf::Containers::DueBy < Wf::FilterContainer
  
  include TicketConstants
  
  TEXT_DELIMITER = ","
  
  STATUS_QUERY = "status not in (#{TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]})"
  
  
  def self.operators
    [:due_by_op]
  end
  
  def split_values
    cond_str = ""
    cond_arr = values[0].split(TEXT_DELIMITER).collect! {|n| n}
    cond_arr.each do |val|
     cond_str <<  " (#{get_due_by_con(val)}) ||"
   end
   cond_str.chomp("||")
 end
 
  def get_due_by_con(val)
    eight_hours = Time.zone.now + 8.hours
    
   due_by_hash = { DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due] => "due_by <= '#{Time.zone.now.to_s(:db)}'",
      DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today] => "due_by >= '#{Time.zone.now.beginning_of_day.to_s(:db)}' and due_by <= '#{Time.zone.now.end_of_day.to_s(:db)}' ",
      DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo] => "due_by >= '#{Time.zone.now.tomorrow.beginning_of_day.to_s(:db)}' and due_by <= '#{Time.zone.now.tomorrow.end_of_day.to_s(:db)}' ",
      DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight] => "due_by >= '#{Time.zone.now.to_s(:db)}' and due_by <= '#{eight_hours.to_s(:db)}' "}
      
   due_by_hash[val.to_i]
  end

  def sql_condition
    return [" #{STATUS_QUERY} and  (#{split_values}) "] 
  end
  
end
