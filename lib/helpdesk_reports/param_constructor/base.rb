class HelpdeskReports::ParamConstructor::Base
  include HelpdeskReports::Helper::Ticket

  DEFAULT_TIME_TREND = "w"

  attr_accessor :date_range, :report_type, :options

  def initialize options
    @options = options
    @date_range = options[:date_range]
    @direct_export = options[:direct_export] || false
  end

  def build_pdf_params
    options.merge!(options[:trend].symbolize_keys) if @direct_export
    if date_range.nil?
      return {
        date_range: date_range,
        filter_name: options[:filter_name],
        report_type: report_type
      }
    end
    @query_params = build_params
    validate_scope
    @query_params.each do|param|
     validate_time_trend(param)
     optimize_time_trend_for_pdf param if (param[:time_trend] && @direct_export)
    end
    
    get_pdf_params.merge(query_hash: @query_params)
  end

  def get_pdf_params
    params = pdf_param_structure
    if report_type == :glance
      filter_data
      params.merge!({label_hash: @label_hash, nf_hash: @nf_hash})
    end
    params
  end

  def basic_param_structure
    {
      bucket: false,
      bucket_conditions: [],
      group_by: [],
      list: false,
      list_conditions: [],
      model: "TICKET",
      reference: false,
      time_trend: false,
      time_trend_conditions: [],
      date_range: date_range,
      metric: nil,
      scheduled_report: @direct_export ? false : true,
      filter: options[:report_filters].present? ? options[:report_filters] : []
    }
  end

  def pdf_param_structure
    {
      date_range: date_range,
      select_hash: options[:select_hash]||[],
      report_type: report_type,
      filter_name: options[:filter_name],
      trend: {
        trend: options[:trend] || DEFAULT_TIME_TREND,
        resolution_trend: options[:resolution_trend] || DEFAULT_TIME_TREND,
        response_trend: options[:response_trend] || DEFAULT_TIME_TREND,
      }
    }
  end

  #for PDF only selected timetrend(along with any mandatory trends) is needed.
  def optimize_time_trend_for_pdf param
    trend_key = METRIC_TIME_TREND_KEY[report_type][param[:metric].downcase.to_sym]
    
    case report_type
    when :ticket_volume
      time_trend = param[:time_trend_conditions]
      options[trend_key] = get_optimal_time_trend(time_trend) unless time_trend.include?(options[trend_key])
      trend = ["h","dow","y"]
      trend << options[trend_key]
    when :performance_distribution
      trend = ["y"]
      trend << options[trend_key]
    end

    param[:time_trend_conditions] = trend.uniq
  end
  
  def get_optimal_time_trend time_trend
    (time_trend - ["h","dow"]).first
  end

end