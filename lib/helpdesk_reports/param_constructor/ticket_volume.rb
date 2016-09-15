class HelpdeskReports::ParamConstructor::TicketVolume < HelpdeskReports::ParamConstructor::Base

  METRICS = ["RECEIVED_RESOLVED_TICKETS","UNRESOLVED_PREVIOUS_BENCHMARK",
             "RECEIVED_RESOLVED_BENCHMARK","UNRESOLVED_CURRENT_BENCHMARK"]

  DAY_TOGGLE = ['today','yesterday','this_week','previous_week','last_7','last_30','this_month','previous_month']

  TREND_OPTION = { :h   => 'h',
                   :dow => 'dow',
                   :doy => 'doy',
                   :w   => 'w',
                   :mon => 'mon',
                   :qtr => 'qtr',
                   :y   => 'y'
                   }

  def initialize options
    @report_filter_params = options
    @report_type = :ticket_volume
    @trend_conditions  =  TREND_OPTION.values
    super options
  end

  def build_params
    query_params
  end

  def query_params
    if basic_param_structure[:scheduled_report]
      @trend_conditions = [TREND_OPTION[:h], TREND_OPTION[:dow], TREND_OPTION[:y]]
      conditions = @report_filter_params[:date]["period"] || @report_filter_params[:date]["date_range"]

      if ( DAY_TOGGLE.include?(conditions) || (1..31).include?(conditions) )
        options[:trend] = TREND_OPTION[:doy]
        @trend_conditions << TREND_OPTION[:doy]
      else
        options[:trend] = TREND_OPTION[:mon]
        @trend_conditions << TREND_OPTION[:mon]
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
