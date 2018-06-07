module Dashboard::TrendCountMethods
  include Helpdesk::TicketFilterMethods
  include Search::Dashboard::AggregationMethods
  include Cache::Memcache::Dashboard::Custom::CacheData

  DEFAULT_TREND = ["unresolved", "overdue", "due_today", "on_hold", "open", "new"]
  SCHEMA_LESS_COLUMNS = {
      :product_id => "helpdesk_schema_less_tickets.product_id"
    }

  private

    def filtered_doc_count(filter_type)
      action_hash = build_action_hash(filter_type)
      if es_enabled
        Search::Filters::Docs.new(action_hash, negative_conditions(filter_type)).count(Helpdesk::Ticket)
      else
        filter_params = {:data_hash => action_hash.to_json}
        default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      end
    end

    def filtered_counts
      query_body = construct_query_body
      result = Search::Filters::Docs.new(query_body).bulk_count(@aggregation_options)
      @aggregation_options ? parse_filter_agg_result(result) : parse_filter_result(result)
    end

    def build_action_hash(filter_type)
      action_hash = default_filter?(filter_type) ? default_filter_data(filter_type) : custom_filter_data(filter_type.to_i)
      filter_condition.each do |filter_key, filter_value|
        action_hash.push({ 'condition' => filter_key.eql?(:product_id) ? SCHEMA_LESS_COLUMNS[filter_key] : filter_key, 'operator' => 'is_in', 'value' => filter_value.join(',') }) if filter_value.present?
      end
      action_hash.push({ 'condition' => 'responder_id', 'operator' => 'is_in', 'value' => User.current.id }) if is_agent && @with_permissible != false
      action_hash
    end

    def construct_query_body
      query_body = ""
      trends.each_with_index do |filter_type, i|
        query_params = filter_query(filter_type.to_s)
        query_params.merge!(aggregation_with_missing_field(@aggregation_options[i]['group_by_field'][1], @limit, true, @aggregation_options[i]['sort'] || 'desc')) if @aggregation_options
        query_body << "{}\n#{query_params.to_json}\n"
      end
      query_body
    end

    def filter_query(filter_type)
      action_hash = build_action_hash(filter_type)
      Search::Filters::Docs.new(action_hash, negative_conditions(filter_type), @with_permissible).payload_params
    end

    def parse_filter_result(result)
      Hash[trends.map(&:to_s).map(&:to_sym).zip result]
    end

    def parse_filter_agg_result(result)
      result.each_with_index.map do |r, i|
        r.merge({ 'group_by' => @aggregation_options[i]['group_by_field'][0] })
      end
    end

    def custom_filter_data(filter_type)
      ticket_filter = @dashboard_id ? load_filter_from_cache(filter_type) : Account.current.ticket_filters.find_by_id(filter_type)
      ticket_filter ? ticket_filter.data[:data_hash] : []
    end

    def load_filter_from_cache(filter_type)
      @ticket_filters ||= dashboard_filters_from_cache(@dashboard_id)
      @ticket_filters.select { |tf| tf.id == filter_type }[0]
    end

    def default_filter_data(filter_type)
      Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_type.to_s) || []
    end

    def negative_conditions(filter_type)
      # Only unresolved tickets are queried for default filters
      default_filter?(filter_type) && filter_type.to_s == 'unresolved' ? [{ 'condition' => 'status', 'operator' => 'is_not', 'value' => "#{RESOLVED},#{CLOSED}" }] : []
    end

    def default_filter?(filter_type)
      filter_type.to_i == 0
    end
end
