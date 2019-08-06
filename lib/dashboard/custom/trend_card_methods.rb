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
  ALL_TYPES = 0

  REPORTS_TIMEOUT = 5

  private

    def fetch_redshift_data(req_params)
      received, expiry, dump_time = Dashboard::RedshiftRequester.new(req_params, REPORTS_TIMEOUT).fetch_records
      if is_redshift_error?(received)
        dashboard_id = @dashboard.id if @dashboard
        Rails.logger.info "Error in TrendCard query: #{Account.current.id}: #{dashboard_id}: #{received.inspect}"
        return { error: 'Reports service unavailable', status: 503 }
      end
      { data: received, last_dump_time: dump_time }
    end

    def fetch_date_range(date_range)
      case date_range
      when 1
        format_date(Time.zone.now)
      when 2
        format_date(Time.zone.now.beginning_of_week)
      when 3
        format_date(Time.zone.now.beginning_of_month)
      when 4
        format_date(6.days.ago)
      when 5
        format_date(29.days.ago)
      end
    end

    # Custom dashboard queries and thus uses account time zone 
    def fetch_redshift_req_params(options, refresh_interval = nil)
      Time.use_zone(Account.current.time_zone) do
        req_params = {
          time_trend: false,
          time_trend_conditions: [],
          reference: true,
          date_range: fetch_date_range(options[:date_range].to_i),
          metric: TREND_METRICS_MAPPING[options[:metric].to_i],
          time_zone: Time.zone.name
        }
        req_params[:refresh_frequency] = refresh_interval if refresh_interval
        req_params[:filter] = construct_redshift_filter(options)
        req_params
      end
    end

    def construct_redshift_filter(options)
      filter_params = []
      filter_params << construct_redshift_group_filter(options[:group_ids])
      filter_params << construct_redshift_product_filter(options[:product_id])
      filter_params << construct_redshift_ticket_type_filter(options[:ticket_type])
      filter_params.compact
    end

    def construct_redshift_group_filter(group_ids)
      group_ids = group_ids.join(',') if group_ids.present?
      redshift_group_filter(group_ids) if group_ids && group_ids.to_i != ALL_GROUPS
    end

    def construct_redshift_product_filter(product_id)
      redshift_product_filter(product_id) if product_id.to_i != ALL_PRODUCTS
    end

    def construct_redshift_ticket_type_filter(ticket_type)
      redshift_ticket_type_filter(ticket_type) if ticket_type.to_i != ALL_TYPES
    end

    def format_date(start_date, end_date = Time.zone.now)
      "#{start_date.strftime('%d %b, %Y')} - #{end_date.strftime('%d %b, %Y')}"
    end
end
