class HelpdeskReports::Formatter::Ticket::Glance
  
  include HelpdeskReports::Util::Ticket
  
  attr_accessor :result

  def initialize data, args = {}
    @result = data
  end
  
  def perform
    placeholders_for_not_applicable
    set_others_key_at_last
    result
  end
  
  def placeholders_for_not_applicable
    result.each do |metric, res|
      res.symbolize_keys!
      next if res[:error].present? || bucket_metric?(metric)     
      res.each do |gp_by, values|
        if gp_by == :general
          values[:metric_result] = NA_PLACEHOLDER_GLANCE if values[:metric_result] == NOT_APPICABLE
        end
      end
    end
  end
  
  def bucket_metric? metric
    metric.split("_").last == "BUCKET"
  end
  
  def set_others_key_at_last
    result.each do |metric, res|
      res.symbolize_keys!
      next if res[:error].present? || bucket_metric?(metric)     
      res.each do |gp_by, values|
        next if gp_by == :general
        if values[PDF_GROUP_BY_LIMITING_KEY]
          tmp = values[PDF_GROUP_BY_LIMITING_KEY]
          values.delete(PDF_GROUP_BY_LIMITING_KEY)
          values.merge!(PDF_GROUP_BY_LIMITING_KEY => tmp)
        end
      end
    end
  end

end