class HelpdeskReports::Formatter::Ticket::Glance
  
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
        values = values.to_a
        not_numeric = values.collect{|i| i unless i.second.is_a? Numeric}.compact
        values = (values - not_numeric).sort_by{|i| i.second}.reverse!
        res[gp_by] = (values|not_numeric).to_h
      end
    end
  end

end