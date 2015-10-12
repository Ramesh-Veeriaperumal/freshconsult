class HelpdeskReports::Formatter::Ticket::CustomerReport
  
  include HelpdeskReports::Util::Ticket
  
  attr_accessor :result

  def initialize data, args = {}
    @result = data
  end
  
  def perform
    sort_group_by_values
    result
  end

  def sort_group_by_values
    result.each do |metric, res|
      res.symbolize_keys!
      next if res[:error].present? 
      res.each do |gp_by, values|
        next if gp_by == :general
        values      = values.select{|k,v| k != NOT_APPICABLE }.to_a
        not_numeric = values.collect{|i| i unless i.second.is_a? Numeric}.compact
        values      = (values - not_numeric)
        asc_values  = values.sort_by{|i| [i.second, i.first] }[0..4] 
        des_values  = values.sort_by{|i| [-i.second,i.first] }[0..4] 
        res[gp_by]  = {} 
        res[gp_by][:ASC]  = (asc_values|not_numeric).to_h
        res[gp_by][:DESC] = (des_values|not_numeric).to_h
      end
    end
  end

end