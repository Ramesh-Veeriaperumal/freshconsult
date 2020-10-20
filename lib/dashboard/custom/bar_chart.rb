class Dashboard::Custom::BarChart < Dashboards
  CONFIG_FIELDS = [:ticket_filter_id, :categorised_by, :representation].freeze
  ID_FIELDS = ['source', 'priority', 'status', 'responder_id', 'group_id', 'internal_group_id',
  'internal_agent_id', 'requester_id', 'product_id', 'owner_id', 'sl_skill_id', 'association_type'].freeze

  ES_FIELD_NAME_MAPPING = {
    requester: 'requester_id',
    group: 'group_id',
    agent: 'responder_id',
    product: 'product_id',
    internal_agent: 'internal_agent_id',
    internal_group: 'internal_group_id'
  }.freeze
  GROUP_OPTIONS_FOR_ES = ['representation'].freeze

  CACHE_EXPIRY = 60
  WIDGET_LIMIT = 7
  VIEW_ALL_LIMIT = 100
  REFRESH_INTERVAL = 30
  NUMBER = 0

  def initialize(dashboard, options = {})
    @dashboard = dashboard
    @widget_trends = fetch_views || preview_trend(options)
    @agg_options = fetch_aggs || [fetch_agg_options(options)]
    @view_all = options[:view_all]
  end

  def result
    fetch_result
  end

  def preview
    fetch_agg_data.to_h[nil]
  end

  private

    def fetch_views
      return unless @dashboard
      @widgets = @dashboard.bar_chart_widgets_from_cache
      @widgets.map do |widget|
        filter_id = widget.ticket_filter_id || widget.config_data['ticket_filter']
        [widget.id, filter_id]
      end
    end

    def fetch_aggs
      return unless @dashboard
      @ticket_fields = Account.current.ticket_fields_from_cache
      @widgets.map do |widget|
        fetch_agg_options(widget.config_data)
      end
    end

    def fetch_agg_options(options, limit = WIDGET_LIMIT)
      @ticket_fields = Account.current.ticket_fields_from_cache
      preview_options = options.slice(*GROUP_OPTIONS_FOR_ES)
      preview_options['group_by_field'] = group_by_field_options(options['categorised_by'].to_i)
      preview_options
    end

    def group_by_field_options(group_by)
      ticket_field = @ticket_fields.select { |tf| tf.id == group_by }[0]
      if ticket_field
        if ticket_field.default?
          return [group_by, ES_FIELD_NAME_MAPPING[ticket_field.name.to_sym] || ticket_field.name]
        else
          return [group_by, ticket_field.column_name]
        end
      else
        return []
      end
    end

    def fetch_result
      return [] if @widgets.empty?
      fetch_agg_data.map do |result|
        {
          id: result[0],
          widget_data: result[1]
        }
      end
    end

    def fetch_agg_data
      count_result = Dashboard::SearchServiceTrendCount.new(trend_count_options).fetch_count
      count_result = parse_search_count_result(count_result)
      Rails.logger.info "Count response:: #{count_result.inspect}"
      count_result
    end

    def trend_count_options
      options = {
        trends: @widget_trends.map(&:second),
        with_permissible: false,
        agg_options: @agg_options,
        limit: (@view_all ? VIEW_ALL_LIMIT : WIDGET_LIMIT)
      }
      options.merge!({ dashboard_id: @dashboard.id }) if @dashboard
      options
    end

    def parse_count_result(count_result)
      result = []
      @widget_trends.each_with_index do |trend, i|
        result << [trend[0], parse_agg_result(count_result[i], @agg_options[i])]
      end
      result
    end

    def parse_search_count_result(count_result)
      result = []
      @widget_trends.each_with_index do |trend, i|
        result<<[trend[0], parse_aggs_result(count_result["results"][i.to_s], @agg_options[i])]
      end
      result
    end

    def parse_aggs_result(result,options)
      id_field = ID_FIELDS.include?(options['group_by_field'][1])
      data = result['results'].map do |values|
          { name: id_field ? values['value'].to_i : values['value'], data: [(options['representation'].to_i == NUMBER ? values['count'] : (values['count'].to_f * 100 / result['total']).round(1))] }
      end
      { group_by: options['group_by_field'][0], data: data }
    end

    def parse_agg_result(result, options)
      # Requester and compnay is not aggregatable. Might come up in future
      # if options['group_by_field'][1] == 'requester_id'
      #   data = agg_result_for_contacts(result, options)
      # else
      data = result[:doc_counts]['name']['buckets'].map do |r|
        { name: r['key'], data: [(options['representation'].to_i == NUMBER ? r['doc_count'] : (r['doc_count'].to_f * 100 / result[:total]).round(1))] }
      end
      { group_by: result['group_by'], data: data }
    end

    # def agg_result_for_contacts(result, options)
    #   requester_ids = result[:doc_counts]['name']['buckets'].map { |r| r['key'] }
    #   requesters = Account.current.users.select([:id, :name]).find_all_by_id(requester_ids)
    #   data = result[:doc_counts]['name']['buckets'].map do |r|
    #     contact = requesters.select { |requester| requester.id == r['key'] }[0]
    #     next unless contact
    #     contact_data = { id: contact.id, name: contact.name }
    #     result_data = [(options['representation'].to_i == NUMBER ? r['doc_count'] : (r['doc_count'].to_f * 100 / result[:total]).round(1))]
    #     { name: r['key'], data: result_data, contact: contact_data }
    #   end
    # end

    def preview_trend(options)
      # nil to accomodate for the preview call for bar_chart widget
      [[nil, options[:ticket_filter_id]]]
    end

    def parse_filter_id(ticket_filter_id)
      ticket_filter_id.to_i.zero? ? ticket_filter_id : ticket_filter_id.to_i
    end

    class << self
      include Dashboard::Custom::WidgetConfigValidationMethods

      def valid_config?(options)
        @config_errors = []
        CONFIG_FIELDS.each do |field|
          @config_errors << field.to_s unless options[field] && safe_send("validate_#{field}", options[field])
        end
        @config_errors.empty? ? true : { fields: @config_errors }
      end
    end
end
