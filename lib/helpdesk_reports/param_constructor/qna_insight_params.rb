class HelpdeskReports::ParamConstructor::QnaInsightParams < HelpdeskReports::ParamConstructor::Base
  include HelpdeskReports::Constants::QnaInsights

  def initialize (params )
    @report_type = :qna_insight
    @is_qna = params[:report_type]==REPORT_TYPE[:qna]
    options = @is_qna ? params[:question] : params
    options[:direct_export] = true # to avoid schedule report true in rs request 
    super options
  end


  def build_params
    transform_date_range
    basic_params = basic_param_structure
    basic_params[:scheduled_report] = false
    if @is_qna
      transform_qna_request(basic_params)
    else
      transform_insights_metric(basic_params)
    end
  end

  private
    def transform_qna_request(basic_params)
      if is_specify_query?
        basic_params[:group_by] = [QNA_GROUP_BY[options[:question_type]]]
        basic_params[:sorting] = true
        basic_params[:metric] = get_metric_for_specific_qna(options[:metric])
        basic_params[:fetch_limit] = 1
        basic_params[:sorting_conditions] = INCREASE_BAD_METRICS.include?(options[:metric]) ? 'ASC' : 'DESC'
      else
        basic_params[:time_trend] = true
        basic_params[:time_trend_conditions] = @time_trend_conditions
        basic_params[:date_str] = @date_str
        basic_params[:metric] = options[:metric]
      end
      basic_params[:q_type] = options[:question_type]
      basic_params[:filter] = [{condition:options[:filter_key], operator:"is_in", value:options[:filter_value]}] if options[:filter_key]
      basic_params
    end

    def transform_insights_metric(basic_params)
      if is_simple_insight_metric? && (!is_unresoved_metric?)
        basic_params[:reference] = true 
      elsif is_group_compare_insight_metric?
        basic_params[:group_by] = ['group_id']
      elsif is_agent_compare_in_group_insight_metric?
        basic_params[:group_by] = ['agent_id']
      end
      basic_params[:q_type] = options[:widget_type]
      basic_params[:widget_id] = options[:widget_id]
      basic_params[:metric] = options[:metric]
      filters_applied = options[:filter] || []
      basic_params[:filter] = filters_applied.inject([]) { |arr, filter| arr << {condition:filter[:key], operator:"is_in", value:filter[:value]}}
      if is_unresoved_metric?
        basic_params[:date_range] = set_date_range(@start_date.yesterday)
        new_params = basic_params.deep_dup
        new_params[:date_range] = set_date_range(@end_date)
        basic_params = [basic_params, new_params]
      end
      basic_params
    end

    def transform_date_range
      if @is_qna
        is_specify_query?  ? transform_date_range_without_historic : transform_date_range_with_historic
      else
        transform_date_range_for_insights
      end
    end

    def transform_date_range_for_insights
      time_now = current_account_time
      @start_date = time_now
      @end_date = time_now
      @date_range = set_date_range(@start_date, @end_date)
    end

    def transform_date_range_without_historic
      time_now = current_account_time
      end_date , start_date = nil
      @date_str = options[:date_range]
      case @date_str
        when DATE_RANGE[:today]
          start_date = time_now
          #@time_trend_conditions = TIME_TREND_CONDITIONS[:day]
        when DATE_RANGE[:yesterday]
          start_date = time_now.yesterday
        when DATE_RANGE[:last_week]
          end_date = time_now.prev_week.end_of_week
          start_date = end_date.beginning_of_week
        when DATE_RANGE[:last_month]
          end_date = time_now.prev_month.end_of_month
          start_date = end_date.beginning_of_month
      end
      @date_range = set_date_range(start_date, end_date)
    end

    def transform_date_range_with_historic
      time_now = current_account_time
      end_date , start_date, time_trend_conditions = nil
      @date_str = @is_qna ? options[:date_range] : 'today'
      case @date_str
        when DATE_RANGE[:today]
          end_date = time_now
          start_date = @is_qna ? time_now - 7.days : time_now.yesterday
          @time_trend_conditions = TIME_TREND_CONDITIONS[:day]
        when DATE_RANGE[:yesterday]
          end_date = time_now.yesterday
          start_date = end_date - 7.days
          @time_trend_conditions = TIME_TREND_CONDITIONS[:day]
        when DATE_RANGE[:last_week]
          end_date = time_now.prev_week.end_of_week
          start_date = end_date.prev_week.beginning_of_week
          @time_trend_conditions = TIME_TREND_CONDITIONS[:week]
        when DATE_RANGE[:last_month]
          end_date = time_now.prev_month.end_of_month
          start_date = end_date.prev_month.beginning_of_month
          @time_trend_conditions = TIME_TREND_CONDITIONS[:month]
      end
      @date_range = set_date_range(start_date, end_date)
    end

    def is_customer_query?
      options[:question_type] == QNA_TYPE[:which_customer]
    end

    def is_agent_query?
      options[:question_type] == QNA_TYPE[:which_agent]
    end

    def is_group_query?
      options[:question_type] == QNA_TYPE[:which_group]
    end

    def is_specify_query?
      @is_specify_query ||= options[:question_type] == QNA_TYPE[:which_customer] ||  options[:question_type] == QNA_TYPE[:which_agent] || options[:question_type] == QNA_TYPE[:which_group]
    end

    def current_account_time
      Time.now.in_time_zone(Account.current.time_zone)
    end

    def set_date_range ( start_date , end_date = nil )
      end_date ? start_date.strftime(DATE_FORMATS_TYPES[:f1]) +' - '+ end_date.strftime(DATE_FORMATS_TYPES[:f1]) : start_date.strftime(DATE_FORMATS_TYPES[:f1])
    end

    def is_simple_insight_metric?
      options[:widget_type].to_i == INSIGHTS_METRIC_TYPE[:simple]
    end

    def is_group_compare_insight_metric?
      options[:widget_type].to_i == INSIGHTS_METRIC_TYPE[:group_compare]
    end

    def is_agent_compare_in_group_insight_metric?
      options[:widget_type].to_i == INSIGHTS_METRIC_TYPE[:agent_compare]
    end

    def is_unresoved_metric?
      options[:metric] == UNRESOLVED_TICKETS
    end

    def get_metric_for_specific_qna(metric)
      # if not number query, append _QNA
      if(METRIC_TO_QUERY_TYPE[metric.to_sym] == QUERY_RESPONSE_TYPES[:count])
        return metric
      else 
        return metric+QNA_SUFFIX
      end
    end
end
