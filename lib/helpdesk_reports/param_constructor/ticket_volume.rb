class HelpdeskReports::ParamConstructor::TicketVolume < HelpdeskReports::ParamConstructor::Base

  METRICS = ["RECEIVED_RESOLVED_TICKETS","UNRESOLVED_PREVIOUS_BENCHMARK",
             "RECEIVED_RESOLVED_BENCHMARK","UNRESOLVED_CURRENT_BENCHMARK"]
  
  DAY_TOGGLE = ['today','yesterday','this_week','previous_week','last_7','this_month','previous_month']
  
  def initialize options
    @report_filter_params = options
    @report_type = :ticket_volume
    @trend_conditions  =  ["h", "dow", "doy", "w", "mon", "qtr", "y"]
    super options
  end
  
  def build_params
    query_params
  end

  def query_params
    if basic_param_structure[:scheduled_report] 
      @trend_conditions = ["h","dow","y"]
       conditions = @report_filter_params[:date]["period"] || @report_filter_params[:date]["date_range"]
        @trend_conditions =   case conditions
                              when  *DAY_TOGGLE, 6, 29
                               options[:trend] = "doy"
                               @trend_conditions << "doy"
                              else 
                               options[:trend] = "mon"
                               @trend_conditions << "mon"
                              end  
    end  
    tv_params = {
        time_trend: true,
        time_trend_conditions: @trend_conditions.uniq,
        metric: "RECEIVED_RESOLVED_TICKETS",
    }

    METRICS.inject([]) do |params, metric|
      query = basic_param_structure.merge(tv_params)
      query[:metric] = metric
      params << query
    end

  end

end