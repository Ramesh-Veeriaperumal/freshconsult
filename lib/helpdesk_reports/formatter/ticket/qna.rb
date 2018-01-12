class HelpdeskReports::Formatter::Ticket::Qna

  include HelpdeskReports::Constants::QnaInsights
  include ApplicationHelper
  attr_accessor :metric, :date_str, :start_date, :end_date , :value1, :value2, :v_direction, :v_status, :v_value, :data
  def initialize data, args = {}
    @args = args
    @date_str    = args[:date_str]
    dates        = args[:date_range].split("-")
    @metric      = args[:metric]
    @q_type      = args[:q_type]
    @data        = data[metric]
    @start_date  = DateTime.parse(dates[0])
    @end_date    = dates.length > 1 ? DateTime.parse(dates[1]) : start_date
  end

  def perform
    return {error: { code: 551,  message:I18n.t('helpdesk_reports.something_went_wrong_msg') } } unless data["errors"].nil? # custom error code 551 to handle server errors
    
    if is_specify_query?
      parse_specific_data
    else
      parse_data
      calculate_variance
    end
    construct_qna_response
  end

  def construct_qna_response

    metric_val = metric.chomp(QNA_SUFFIX)
    result_hash =  {
      metric: metric_val,
      start_date: start_date,
      end_date: end_date,
      val1: value1,
      val2: value2,
      metric_type: METRIC_TO_QUERY_TYPE[metric_val.to_sym]
    }
    unless is_specify_query?
      result_hash[:variance] = get_variance_data
      result_hash[:chart_data] = get_chart_data
    end
    result_hash
  end

  def get_variance_data
    {
      direction: v_direction,
      status: v_status,
      value: v_value
    }
  end

  private

  def parse_specific_data
    @value1,@value2 = nil
    Sharding.run_on_slave do
      if data.any? && data["errors"].nil?
        data.symbolize_keys!
        if @q_type == QNA_TYPE[:which_customer]
          id , value = data[:company_id].first
          company = Account.current.companies.find_by_id(id)
          @value1 = company ? company.name : nil
          @value2 = value
        elsif @q_type == QNA_TYPE[:which_agent]
          id , value = (data[:actor_id] || data[:agent_id]).first
          agent = Account.current.users.find_by_id(id)
          @value1 = agent ? { name:agent.name, url: user_avatar(agent, :thumb, "preview_pic circle", {:width => "30px", :height => "30px" })} : nil
          @value2 = value
        elsif @q_type == QNA_TYPE[:which_group]
          id , value = data[:group_id].first
          group = Account.current.groups.find_by_id(id)
          @value1 = group ? group.name : nil
          @value2 = value
        end
      end
    end
  end

  def parse_data
    data.symbolize_keys!
    primary_key = @args[:time_trend_conditions][0].to_sym # for chart
    date_range_type = date_str ==DATE_RANGE[:last_month] || date_str ==DATE_RANGE[:last_week]
    @data_arr = data[primary_key] || {}
    if(date_range_type)
      @variance_hash =  data[@args[:time_trend_conditions][1].to_sym] || {}# for week and month grouping
    else
      @variance_hash = data[primary_key] || {}
    end
  end

  def get_chart_data
    return nil unless @data_arr.any?
    x_axis = []
    y_axis = []
    is_month = date_str == DATE_RANGE[:last_month]
    is_count_or_pc = METRIC_TO_QUERY_TYPE[metric.to_sym] == QUERY_RESPONSE_TYPES[:count] || METRIC_TO_QUERY_TYPE[metric.to_sym] == QUERY_RESPONSE_TYPES[:percentage]
    start_dt = @start_date

    while start_dt <= @end_date
      key = nil
      x_axis_point = start_dt.strftime(DATE_FORMATS_TYPES[:f2])
      if is_month
        end_dt = start_dt.end_of_week
        end_dt = end_date if end_dt > end_date
        key = is_count_or_pc ? start_dt.strftime(DATE_FORMATS_TYPES[:f4]) : start_dt.strftime(DATE_FORMATS_TYPES[:f3])+' - '+ end_dt.strftime(DATE_FORMATS_TYPES[:f3])
        start_dt = start_dt.next_week
      else
        key = is_count_or_pc ? start_dt.strftime(DATE_FORMATS_TYPES[:f2]) :  start_dt.strftime(DATE_FORMATS_TYPES[:f3])
        start_dt =  start_dt.tomorrow
      end
      value = @data_arr[key] || 0
      x_axis.push(x_axis_point)
      y_axis.push(value)
    end
    { categories: x_axis,
      values: y_axis }
  end

  def calculate_variance
    val1_key, val2_key = nil #val1 - current , val2 is historic
    query_type = METRIC_TO_QUERY_TYPE[metric.to_sym]
    @value1 , @value2 = 0
    case @date_str
    when DATE_RANGE[:today],DATE_RANGE[:yesterday]
      if query_type == QUERY_RESPONSE_TYPES[:count] || query_type == QUERY_RESPONSE_TYPES[:percentage]
        val1_key = @end_date.strftime(DATE_FORMATS_TYPES[:f2])
        val2_key = @end_date.yesterday.strftime(DATE_FORMATS_TYPES[:f2])
      else #query_type == "Avg"
        val1_key = @end_date.strftime(DATE_FORMATS_TYPES[:f3])
        val2_key = @end_date.yesterday.strftime(DATE_FORMATS_TYPES[:f3])
      end
    when DATE_RANGE[:last_week]
      if query_type == QUERY_RESPONSE_TYPES[:count] || query_type == QUERY_RESPONSE_TYPES[:percentage]
        val1_key = @end_date.beginning_of_week.strftime(DATE_FORMATS_TYPES[:f4])
        val2_key = @start_date.strftime(DATE_FORMATS_TYPES[:f4])
      else #query_type == "Avg"
        val1_key = @end_date.beginning_of_week.strftime(DATE_FORMATS_TYPES[:f3])+' - '+@end_date.strftime(DATE_FORMATS_TYPES[:f3])
        val2_key = @start_date.strftime(DATE_FORMATS_TYPES[:f3])+' - '+@start_date.end_of_week.strftime(DATE_FORMATS_TYPES[:f3])
      end
    when DATE_RANGE[:last_month]
      if query_type == QUERY_RESPONSE_TYPES[:count] || query_type == QUERY_RESPONSE_TYPES[:percentage]
        val1_key = @end_date.strftime(DATE_FORMATS_TYPES[:f5])
        val2_key = @start_date.strftime(DATE_FORMATS_TYPES[:f5])
      else #query_type == "Avg"
        val1_key = @end_date.strftime(DATE_FORMATS_TYPES[:f6])
        val2_key = @start_date.strftime(DATE_FORMATS_TYPES[:f6])
      end
    end
    current_metric = @variance_hash[val1_key] || 0
    historic_metric = @variance_hash[val2_key] || 0
    diff = current_metric - historic_metric
    is_increased = diff > 0
    @v_status = is_increased ^ INCREASE_BAD_METRICS.include?(metric) ? VARIANCE_STATUS[:positive] : VARIANCE_STATUS[:negative] 
    @v_direction = is_increased ? VARIANCE_DIRECTION[:up] : VARIANCE_DIRECTION[:down] 
    @v_value = percent_of(diff.abs,historic_metric)
    if current_metric == historic_metric
      @v_status = VARIANCE_STATUS[:neutral]
      @v_direction = VARIANCE_DIRECTION[:level]
      @v_value = 0
    end
    @value1 = current_metric
    @value2 = historic_metric
  end

  def percent_of(n1, n2)
    if(n1==0 || n2==0)
      return 100
    end
    (n1.to_f / n2.to_f * 100.0).round
  end

  def is_specify_query?
    @is_specify_query ||= @q_type == QNA_TYPE[:which_customer] || @q_type == QNA_TYPE[:which_agent] || @q_type == QNA_TYPE[:which_group]
  end

end
