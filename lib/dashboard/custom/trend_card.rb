class Dashboard::Custom::TrendCard < Dashboards
  include Cache::Memcache::Dashboard::CacheData
  include MemcacheKeys

  CONFIG_FIELDS = [:group_ids, :product_id, :metric, :metric_type, :date_range].freeze

  CACHE_EXPIRY = 3600
  REFRESH_INTERVAL = 30
  ALL_PRODUCTS = 0

  METRIC_TYPE_MAPPING = {
    1 => 'ticket',
    2 => 'time',
    3 => 'sla'
  }.freeze

  METRICS_MAPPING = {
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

  DATE_FIELDS_MAPPING = {
    1 => 'Today',
    2 => 'This week',
    3 => 'This month'
  }.freeze

  def initialize(dashboard, options = {})
    @dashboard = dashboard
    @options = options
  end

  def result
    fetch_widgets_redshift_data
  end

  def preview
    { data: fetch_redshift_data(fetch_redshift_req_params(@options))[:data][0]['result'] }
  end

  private

    # def cache_custom_dashboard_metric
    #   redshift_cache_data CUSTOM_DASHBOARD_METRIC, "process_custom_dashboard_results", "redshift_custom_dashboard_cache_identifier"
    # end

    def fetch_widgets_redshift_data
      return unless @dashboard
      @widgets = @dashboard.trend_card_widgets_from_cache
      return [] if @widgets.length < 1
      redshift_req_params = @widgets.map { |widget| fetch_redshift_req_params(widget.config_data) }
      result = fetch_redshift_data(redshift_req_params)
      return result if result[:error]
      @widgets.each_with_index.map do |widget, i|
        {
          id: widget.id,
          widget_data: result[:data][i]['result'] || 0
        }
      end
      # { data: widgets_data, last_dump_time: result[:data][-1]['last_dump_time'] }
    end

    def fetch_redshift_data(req_params)
      received, expiry, dump_time = Dashboard::RedshiftRequester.new(req_params).fetch_records
      return { error: "Reports service unavailable", status: 503 } if is_redshift_error?(received)
      { data: received, last_dump_time: dump_time }
    end

    def fetch_date_range(date_range)
      if date_range == 1
        format_date(Time.now)
      elsif date_range == 2
        format_date(Time.now.beginning_of_week)
      elsif date_range == 3
        format_date(Time.now.beginning_of_month)
      end
    end

    def fetch_redshift_req_params(options, refresh_interval = nil)
      req_params = {
        time_trend: false,
        time_trend_conditions: [],
        reference: true,
        date_range: fetch_date_range(options[:date_range].to_i),
        metric: METRICS_MAPPING[options[:metric].to_i]
      }
      req_params[:refresh_frequency] = refresh_interval if refresh_interval
      req_params[:filter] = construct_redshift_filter(options[:group_ids].present? ? options[:group_ids].join(',') : nil, options[:product_id])
      req_params
    end

    def construct_redshift_filter(group_ids, product_id)
      filter_params = []
      filter_params << redshift_group_filter(group_ids) if group_ids
      filter_params << redshift_product_filter(product_id) if product_id && product_id.to_i != ALL_PRODUCTS
      filter_params
    end

    def format_date(start_date, end_date = Time.zone.now)
      "#{start_date.strftime('%d %b, %Y')} - #{end_date.strftime('%d %b, %Y')}"
    end

    class << self
      include Dashboard::Custom::WidgetConfigValidationMethods

      def valid_config?(options)
        @config_errors = []
        CONFIG_FIELDS.each do |field|
          @config_errors << field.to_s unless safe_send("validate_#{field}", options[field])
        end
        @config_errors.empty? ? true : { fields: @config_errors }
      end
    end
end
