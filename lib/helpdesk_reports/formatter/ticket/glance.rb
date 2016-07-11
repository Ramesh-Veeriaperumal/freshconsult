class HelpdeskReports::Formatter::Ticket::Glance 

  include HelpdeskReports::Util::Ticket
  
  attr_accessor :result, :glance_output, :current_values, :previous_values, :group_by_metric

  COUNT_METRICS       = ["received_tickets","resolved_tickets","reopened_tickets","unresolved_tickets"]
  SLA_METRICS         = ["fcr_tickets", "response_sla", "resolution_sla"]
  DEPENDENT_METRICS   = ["avg_resolution_time","resolution_sla","fcr_tickets"]
  INDEPENDENT_METRICS = ["received_tickets","resolved_tickets"]
  
  CURRENT_METRICS    = INDEPENDENT_METRICS + DEPENDENT_METRICS
  HISTORIC_METRICS   = ["reopened_tickets","avg_first_response_time","avg_response_time","avg_first_assign_time","response_sla"]
  UNRESOLVED_METRICS = ["unresolved_tickets"]  

  def initialize data, args = {}
    @result = data
    @pdf_export = args[:pdf_export]
    @glance_output = {}
  end
 
  def perform 
    if @pdf_export
      result.each do |metric, res|
        next if (res.is_a?(Hash) && (res['errors'].present? || bucket_metric?(metric)))     
        if metric == "UNRESOLVED_PREVIOUS_BENCHMARK" 
          @unresolved_previous_result = (res.is_a?(Hash) && res['error'] ) ? [] : res
        else
          res.each do |gp_by, values|
            if gp_by == "general"
              values["metric_result"] = NA_PLACEHOLDER_GLANCE if values["metric_result"] == NOT_APPICABLE
            else
              #to set -others key at last
              values[PDF_GROUP_BY_LIMITING_KEY] = values.delete PDF_GROUP_BY_LIMITING_KEY if values[PDF_GROUP_BY_LIMITING_KEY]
            end
          end  
        end
      end
        #calculating unresolved benchmark
        if result["UNRESOLVED_TICKETS"] && result["UNRESOLVED_TICKETS"][:general]
          pvalues = @unresolved_previous_result[0]["unresolved_count"].to_i
          cvalues  = @result["UNRESOLVED_TICKETS"][:general][:metric_result]
          result["UNRESOLVED_TICKETS"][:general][:diff_percentage] = calculate_difference_percentage(pvalues,cvalues,"UNRESOLVED_TICKETS")
        end
        #Removing group by historic status if both status and historic status are same
        # if(result["UNRESOLVED_TICKETS"] && (result["UNRESOLVED_TICKETS"][:status] == result["UNRESOLVED_TICKETS"][:historic_status]))
        #   result["UNRESOLVED_TICKETS"].delete(:historic_status)
        # end
      result.delete("UNRESOLVED_PREVIOUS_BENCHMARK")
      result
    else
      result.each do |metric, res|
        if metric == "GLANCE_CURRENT"
          @current_result =  (res.is_a?(Hash) && res['errors'] ) ? [] : res
        elsif metric == "GLANCE_HISTORIC"  
          @historic_result = (res.is_a?(Hash) && res['error'] ) ? [] : res
        elsif metric == "UNRESOLVED_PREVIOUS_BENCHMARK" 
          @unresolved_previous_result = (res.is_a?(Hash) && res['error'] ) ? [] : res
        elsif metric == "UNRESOLVED_CURRENT_BENCHMARK" 
          @unresolved_current_result = (res.is_a?(Hash) && res['error'] ) ? [] : res
        elsif bucket_metric?(metric)
          glance_output[metric] = res
        else
          @group_by_metric = metric
        end
      end

      #condition to check for query from fetch_active_metric
      construct_metric_value if (result.has_key?('GLANCE_CURRENT') && result.has_key?('GLANCE_HISTORIC'))

      sort_group_by_chart_values
      glance_output[group_by_metric] = glance_output[group_by_metric] || {}
      glance_output[group_by_metric].reverse_merge!(result[group_by_metric])
      
      #Removing group by historic status if both status and historic status are same
      # if(glance_output["UNRESOLVED_TICKETS"] && (glance_output["UNRESOLVED_TICKETS"][:status] == glance_output["UNRESOLVED_TICKETS"][:historic_status]))
      #   glance_output["UNRESOLVED_TICKETS"].delete(:historic_status)
      # end
      glance_output
    end
  end

  def construct_metric_value
    @current_values , @previous_values = {}, {}

    if @current_result.empty? 
      set_default_value(CURRENT_METRICS)
    else
      split_values_based_on_benchmark(@current_result)
      set_value(INDEPENDENT_METRICS)
      current_values["resolved_tickets"] == 0 ? set_default_value(DEPENDENT_METRICS) #Not processing resolved dependent metrics if no resolved tickets.
                                               : set_value(DEPENDENT_METRICS)
    end

    if @historic_result.empty?
      set_default_value(HISTORIC_METRICS)
    else
      split_values_based_on_benchmark(@historic_result)
      set_value(HISTORIC_METRICS)
    end

    if @unresolved_current_result.empty? && @unresolved_previous_result.empty?
      set_default_value(UNRESOLVED_METRICS)
    else
      current_values["unresolved_tickets"]  = @unresolved_current_result[0]["unresolved_count"]
      previous_values["unresolved_tickets"] = @unresolved_previous_result[0]["unresolved_count"]
      set_value(UNRESOLVED_METRICS)
    end
  end

  def split_values_based_on_benchmark metric_arr
    metric_arr.each do |hash|
      hash["range_benchmark"] == "t" ? current_values.reverse_merge!(hash) : previous_values.reverse_merge!(hash)
    end
  end

  def set_default_value metric_arr
    metric_arr.each { |key| glance_output[key.upcase] = {} }
  end

  def set_value metric_arr
    metric_arr.each do |key|
      metric = current_values[key].to_i
      diff_percentage = calculate_difference_percentage(previous_values[key],current_values[key], key) 
      tickets_count = case
                      when key == 'avg_resolution_time'         #avg_resolution_time will reuse tickets_count from resolved tickets
                        current_values['resolved_tickets']
                      when COUNT_METRICS.include?(key) 
                        current_values[key]
                      else
                        current_values["#{key}_tickets_count"]
                      end
      
      glance_output[key.upcase] = {general: {metric_result: metric, diff_percentage: diff_percentage, tickets_count: tickets_count.to_i} }
    end
  end

  def calculate_difference_percentage previous_val, current_val, metric
      return NOT_APPICABLE if ( previous_val.to_i == 0 || [previous_val, current_val].include?(NOT_APPICABLE) || (SLA_METRICS.include?(metric) && current_val.to_i == 0 ) )
      percentage = (current_val.to_f - previous_val.to_f)*100/ previous_val.to_f
      percentage.round
  end
  
  def bucket_metric? metric
    metric.split("_").last == "BUCKET"
  end

  def sort_group_by_chart_values 
    result[group_by_metric].each do |gp_by, values|
      next if values.is_a?(Hash) && values["errors"]
      values = values.to_a
      next if gp_by == :general 
      values = values.sort_by{|i| i.second[:value]}.reverse!
      result[group_by_metric][gp_by] = values.to_h
    end
  end

end
