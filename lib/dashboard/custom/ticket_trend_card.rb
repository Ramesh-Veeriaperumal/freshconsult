class Dashboard::Custom::TicketTrendCard < Dashboards
  include Cache::Memcache::Dashboard::CacheData
  include Dashboard::Custom::TrendCardMethods
  # include MemcacheKeys

  CONFIG_FIELDS = [:group_ids, :product_id, :metric, :date_range].freeze

  CACHE_EXPIRY = 3600

  METRICS_MAPPING = {
    1 => 'RECEIVED_TICKETS',
    2 => 'RESOLVED_TICKETS',
    3 => 'REOPENED_TICKETS'
  }
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

    def fetch_widgets_redshift_data
      return unless @dashboard
      @widgets = @dashboard.ticket_trend_card_widgets_from_cache
      return [] if @widgets.empty?
      redshift_req_params = @widgets.map { |widget| fetch_redshift_req_params(widget.config_data) }
      result = fetch_redshift_data(redshift_req_params)
      return result if result[:error] # Error is cached to prevent further hits. Has to be handled better
      @widgets.each_with_index.map do |widget, i|
        {
          id: widget.id,
          widget_data: result[:data][i]['result'] || 0
        }
      end
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

      def validate_metric(metric)
        METRICS_MAPPING[metric.to_i]
      end
    end
end
