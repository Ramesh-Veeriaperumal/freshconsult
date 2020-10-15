class Dashboard::Custom::Scorecard < Dashboards
  ERROR_OPTIONS = { fields: 'ticket_filter_id' }
  CACHE_EXPIRY = 60
  REFRESH_INTERVAL = 30
  CONFIG_FIELDS = [:ticket_filter_id]

  def initialize(dashboard, options = {})
    @dashboard = dashboard
    @widget_trends = fetch_views || preview_trend(options)
    @trends = @widget_trends.map(&:second).uniq
  end

  def result
    fetch_result
  end

  def preview
    {
      count: fetch_count.to_h[nil]
    }
  end

  private

    def fetch_views
      return unless @dashboard
      @widgets = @dashboard.scorecard_widgets_from_cache
      @widgets.map do |widget|
        filter_id = widget.ticket_filter_id || widget.config_data['ticket_filter']
        [widget.id, filter_id]
      end
    end

    def fetch_result
      return [] if @widgets.empty?
      fetch_count.map do |result|
        {
          id: result[0],
          widget_data: {
            count: result[1]
          }
        }
      end
    end

    def fetch_count
      count_result = Dashboard::SearchServiceTrendCount.new(trend_count_options).fetch_count
      parse_search_es_response(count_result['results'])
    end

    def parse_search_es_response(response)
      result = @widget_trends.map do |widget_id, type|
          [widget_id, response[type.to_s]["total"]]
      end
      result
    end

    def trend_count_options
      options = {
        trends: @trends,
        with_permissible: false
      }
      options.merge!({ dashboard_id: @dashboard.id }) if @dashboard
      options
    end

    def parse_count(count_result)
      result = @widget_trends.map do |widget_id, type|
        [widget_id, count_result[type.to_s.to_sym]]
      end
      result
    end

    def preview_trend(options)
      # nil to accomodate for the preview call for scorecard widget
      [[nil, options[:ticket_filter_id]]]
    end

    def parse_filter_id(ticket_filter_id)
      ticket_filter_id.to_i.zero? ? ticket_filter_id : ticket_filter_id.to_i
    end

    class << self
      include Dashboard::Custom::WidgetConfigValidationMethods

      def valid_config?(options)
        options[:ticket_filter_id] && validate_ticket_filter_id(options[:ticket_filter_id]) ? true : ERROR_OPTIONS
      end
    end
end
