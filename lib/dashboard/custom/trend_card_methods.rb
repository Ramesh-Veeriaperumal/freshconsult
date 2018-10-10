module Dashboard::Custom::TrendCardMethods
  TREND_METRICS_MAPPING = {
    1 => 'RECEIVED_TICKETS',
    2 => 'RESOLVED_TICKETS',
    3 => 'REOPENED_TICKETS',
    4 => 'AVG_RESOLUTION_TIME',
    5 => 'AVG_FIRST_RESPONSE_TIME',
    6 => 'AVG_RESPONSE_TIME',
    7 => 'AVG_FIRST_ASSIGN_TIME',
    8 => 'FCR_TICKETS_PERC',
    9 => 'RESPONSE_SLA_QNA',
    10 => 'RESOLUTION_SLA_QNA'
  }.freeze

  ALL_PRODUCTS = 0
  ALL_GROUPS = 0

  REPORTS_TIMEOUT = 5

  private

    def fetch_redshift_data(req_params)
      received, expiry, dump_time = Dashboard::RedshiftRequester.new(req_params, REPORTS_TIMEOUT).fetch_records
      if is_redshift_error?(received)
        Rails.logger.info "Error in TrendCard query: #{Account.current.id}: #{@dashboard.id}: #{received.inspect}"
        return { error: 'Reports service unavailable', status: 503 }
      end
      { data: received, last_dump_time: dump_time }
    end

    def fetch_date_range(date_range)
      case date_range
      when 1
        format_date(Time.now)
      when 2
        format_date(Time.now.beginning_of_week)
      when 3
        format_date(Time.now.beginning_of_month)
      when 4
        format_date(6.days.ago)
      when 5
        format_date(29.days.ago)
      end
    end

    def fetch_redshift_req_params(options, refresh_interval = nil)
      req_params = {
        time_trend: false,
        time_trend_conditions: [],
        reference: true,
        date_range: fetch_date_range(options[:date_range].to_i),
        metric: TREND_METRICS_MAPPING[options[:metric].to_i]
      }
      req_params[:refresh_frequency] = refresh_interval if refresh_interval
      req_params[:filter] = construct_redshift_filter(options[:group_ids].present? ? options[:group_ids].join(',') : nil, options[:product_id])
      req_params
    end

    def construct_redshift_filter(group_ids, product_id)
      filter_params = []
      filter_params << redshift_group_filter(group_ids) if group_ids && group_ids.to_i != ALL_GROUPS
      filter_params << redshift_product_filter(product_id) if product_id && product_id.to_i != ALL_PRODUCTS
      filter_params
    end

    def format_date(start_date, end_date = Time.zone.now)
      "#{start_date.strftime('%d %b, %Y')} - #{end_date.strftime('%d %b, %Y')}"
    end
end