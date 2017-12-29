class HelpdeskReports::Formatter::Ticket::Insight
  include HelpdeskReports::Constants::QnaInsights

  attr_accessor :metric, :date_str, :start_date, :end_date , :value1, :value2, :v_direction, :v_status, :v_value

  def initialize data, args = {}
    @args             = args[:query_params]
    @processed_result = {}
    @report_type      = args[:report_type]
    @is_qna           = false
    @data             = data
  end

  def perform
    unresolved_old = nil
    return {error: { code: 551,  message:I18n.t('helpdesk_reports.something_went_wrong_msg')} } unless @data[nil].nil? # custom error code 551 to handle server errors
    @data.inject({}) do | res, (index, value) |
      request      =  @args[index]
      @metric      = request[:metric]
      @date_str    = request[:date_str]
      dates        = request[:date_range].split("-")
      @widget_type = request[:q_type].to_i
      @start_date  = DateTime.parse(dates[0])
      @end_date    = dates.length > 1 ? DateTime.parse(dates[1]) : start_date
      if value.empty?
        @value1, @value2, @v_direction, @v_status, @v_value = nil
        res[request[:widget_id]] = construct_response
      else
        if is_simple_metric? && (!is_unresolved_metric?)
          parse_simple_metric_data(value)
          res[request[:widget_id]] = construct_response
        elsif is_agent_compare_metric?
          parse_agent_compare_data(value)
          res[request[:widget_id]] = construct_response
        elsif is_group_compare_metric?
          parse_group_compare_data(value , request[:filter][0][:value].split(','))
          res[request[:widget_id]] = construct_response
        elsif is_unresolved_metric?
          if unresolved_old
            parse_unresolved_metric(unresolved_old[:value], value)
            @start_date = unresolved_old[:start_date]
            res[request[:widget_id]] = construct_response
          else
            unresolved_old = {
              value: value,
              start_date: @start_date
            }
          end
        end
      end
      res
    end
  end

  private
  def construct_response
    result_hash =  {
      metric: metric,
      start_date: start_date,
      end_date: end_date,
      val1: value1,
      val2: value2
    }
    result_hash[:variance] = get_variance_data
    result_hash[:metric_type] = METRIC_TO_QUERY_TYPE[metric.to_sym]
    result_hash
  end

  def get_variance_data
    {
      direction: v_direction,
      status: v_status,
      value: v_value
    }
  end

  def parse_unresolved_metric ( old , new_val)
    current_metric =  new_val[:general] ? new_val[:general][:metric_result] : 0
    historic_metric = old[:general] ? old[:general][:metric_result]  : 0
    calculate_diff(current_metric, historic_metric)
  end

  def parse_simple_metric_data ( value)
    value.symbolize_keys!

    if value[:general].nil?
      @value1 = nil
      @value2 = nil
      @v_status = VARIANCE_STATUS[:neutral]
      @v_direction = VARIANCE_DIRECTION[:level]
      @v_value = 0
    else
      value = value[:general]
      current_metric = value[:metric_result].to_i
      diff_percentage = value[:diff_percentage]
      @value1 = current_metric
      @value2 = nil
      if(diff_percentage=='None')
        is_increased = current_metric > 0
        @v_value = 100
        @v_status = is_increased ^ INCREASE_BAD_METRICS.include?(metric) ? VARIANCE_STATUS[:positive] : VARIANCE_STATUS[:negative]
        @v_direction = is_increased ? VARIANCE_DIRECTION[:up] : VARIANCE_DIRECTION[:down]
      elsif diff_percentage == 0
        @v_status = VARIANCE_STATUS[:neutral]
        @v_direction = VARIANCE_DIRECTION[:level]
        @v_value = 0
      else
        is_increased = diff_percentage > 0
        @v_value = diff_percentage.abs
        @v_status = is_increased ^ INCREASE_BAD_METRICS.include?(metric) ? VARIANCE_STATUS[:positive] : VARIANCE_STATUS[:negative]
        @v_direction = is_increased ? VARIANCE_DIRECTION[:up] : VARIANCE_DIRECTION[:down]
      end

    end
  end

  def calculate_diff (current_metric, historic_metric)
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

  def is_simple_metric?
    @widget_type == INSIGHTS_METRIC_TYPE[:simple]
  end

  def is_agent_compare_metric?
    @widget_type == INSIGHTS_METRIC_TYPE[:agent_compare]
  end

  def is_group_compare_metric?
    @widget_type == INSIGHTS_METRIC_TYPE[:group_compare]
  end

  def is_unresolved_metric?
    metric == UNRESOLVED_TICKETS
  end

  def parse_agent_compare_data (value)
    agent_vals = value[:actor_id] || {}
    @value1 = agent_vals.length
    @value2 = nil
    @v_status = nil 
    @v_direction = nil
    if agent_vals.length > 6
      avg_val = agent_vals.values.sum.to_f / agent_vals.length
      avg_min = 0.9 * avg_val
      avg_max = 1.1 * avg_val
      good = 0 
      bad = 0
      agent_vals.values.each do |val|
        bad += 1 if val > avg_max
        good += 1 if val < avg_min
      end
      
      threshold = (agent_vals.length * 0.15).ceil
      if good >= threshold && bad >= threshold
        @value2 = good > bad ? good : bad
        @v_status = good > bad ? VARIANCE_STATUS[:positive] : VARIANCE_STATUS[:negative]
      elsif good >= threshold
        @value2 =  good
        @v_status =VARIANCE_STATUS[:positive]
      elsif bad >= threshold
        @value2 = bad
        @v_status = VARIANCE_STATUS[:negative]
      end
    end
  end

  def parse_group_compare_data (value , (grp1, grp2))
    group_vals = value[:group_id]
    val1 = group_vals[grp1] || 0
    val2 = group_vals[grp2] || 0
    calculate_diff(val1 , val2)
  end

end
