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
  
  TEXT_DELIMITER = ","
  
  EIGHT_HOURS = Time.zone.now + 8.hours
  
  STATUS_QUERY = "status not in (#{TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]},#{TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]})"
  
  DUEBY_CON_HASH = { 1 => "due_by <= '#{Time.zone.now.to_s(:db)}'",
                     2 => "due_by >= '#{Time.zone.now.beginning_of_day.to_s(:db)}' and due_by <= '#{Time.zone.now.end_of_day.to_s(:db)}' ",
                     3 => "due_by >= '#{Time.zone.now.tomorrow.beginning_of_day.to_s(:db)}' and due_by <= '#{Time.zone.now.tomorrow.end_of_day.to_s(:db)}' ",
                     4 => "due_by >= '#{Time.zone.now.to_s(:db)}' and due_by <= '#{EIGHT_HOURS.to_s(:db)}' "}

  def self.operators
    [:due_by_op]
  end
  
  def split_values
    val_arr = value.split(TEXT_DELIMITER)
    val_arr.each do |val|
      value.gsub(val,DUEBY_CON_HASH[val])
    end
    value.gsub(TEXT_DELIMITER,' || ')
  end

  def sql_condition
    return [" #{STATUS_QUERY} and  #{split_values} "] 
  end
  
end
