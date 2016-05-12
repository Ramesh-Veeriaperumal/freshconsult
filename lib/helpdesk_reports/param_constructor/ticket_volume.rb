class HelpdeskReports::ParamConstructor::TicketVolume < HelpdeskReports::ParamConstructor::Base

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
    tv_params = basic_param_structure.merge(tv_params)
    [tv_params]
  end

end