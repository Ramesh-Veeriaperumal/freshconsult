class HelpdeskReports::ParamConstructor::TicketVolume < HelpdeskReports::ParamConstructor::Base

  METRICS = ["RECEIVED_RESOLVED_TICKETS","UNRESOLVED_PREVIOUS_BENCHMARK","RECEIVED_RESOLVED_BENCHMARK","UNRESOLVED_CURRENT_BENCHMARK"]

  def initialize options
    @report_type = :ticket_volume
    @trend_conditions  =  ["h", "dow", "doy", "w", "mon", "qtr", "y"]
    super options
  end

  def build_params
    query_params
  end

  def query_params
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