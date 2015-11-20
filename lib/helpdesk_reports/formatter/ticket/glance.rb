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
      next if res[:error].present? || bucket_metric?(metric)     
      res.each do |gp_by, values|
        if gp_by == :general
          values[:metric_result] == 0 if values[:metric_result] == NA_PLACEHOLDER_GLANCE 
        else
          values = values.to_a
          not_numeric = values.collect{|i| i unless i.second[:value].is_a? Numeric}.compact
          values = (values - not_numeric).sort_by{|i| i.second[:value]}.reverse!
          res[gp_by] = (values|not_numeric).to_h
        end
      end
    end
  end
  
  def bucket_metric? metric
    metric.split("_").last == "BUCKET"
  end

end