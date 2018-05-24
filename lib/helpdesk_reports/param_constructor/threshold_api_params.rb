class HelpdeskReports::ParamConstructor::ThresholdApiParams < HelpdeskReports::ParamConstructor::Base


  LAST_N_DAYS = 30


  def initialize (params , add_options = nil)
    @report_type = 'threshold'
    if add_options
      @busy_hr = add_options[:busy_hr]
      @n_days = add_options[:days_limit]
    end
    @is_busy_hr_request = add_options.nil?
    options = params
    options[:direct_export] = true # to avoid schedule report true in rs request
    super options
  end


  def build_params
    basic_params = basic_param_structure
    if @is_busy_hr_request
      transform_date_range_for_busy_hr
      basic_params[:scheduled_report] = false
      transform_busy_hr_request(basic_params)
    else
      request_arr = [];
      req_template = threshold_count_request(basic_params)
      Rails.logger.info " Contructing Threshold Request for #{@n_days}"
      @n_days.times do |x|
        newreq =  req_template.clone
        set_request_date_time(newreq,x)
        request_arr.push(newreq)
      end
      request_arr
    end

  end

  private
  def transform_busy_hr_request(basic_params)
    basic_params[:time_trend] = true
    basic_params[:time_trend_conditions] = ['h']
    basic_params[:date_range] = @date_range
    basic_params[:metric] = 'RECEIVED_TICKETS'
 
    filters_applied = options[:filter] || []
    basic_params[:filter] = filters_applied.inject([]) { |arr, filter| arr << {condition:filter[:key], operator:"is_in", value:filter[:value]}}
    basic_params
  end

  def threshold_count_request(basic_params)
    basic_params[:metric] = options[:metric]
    filters_applied = options[:filter]|| []
    basic_params[:filter] = filters_applied.inject([]) { |arr, filter| arr << {condition:filter[:key], operator:"is_in", value:filter[:value]}}
    basic_params
  end


  def transform_date_range_for_busy_hr
    time_now = current_account_time
    end_date , start_date = nil
    # @date_str = options[:date_range] : 'today'
    end_date = time_now
    start_date = time_now - LAST_N_DAYS.days
    @date_range = set_date_range(start_date, end_date)
  end

  def set_request_date_time(request, interval)
    time_now = current_account_time
    end_date , start_date = nil
    end_date = time_now - interval.days
    start_date = end_date - LAST_N_DAYS.days
    request[:date_range] = set_date_range(start_date, end_date)
    request[:start_time] = "#{@busy_hr}:00"
    request[:end_time] = "#{@busy_hr}:00"
  end

  def set_date_range ( start_date , end_date = nil )
    start_date.strftime('%d %b,%Y') +' - '+ end_date.strftime('%d %b,%Y')
  end

  def current_account_time
    Time.now.in_time_zone(Account.current.time_zone)
  end

end
