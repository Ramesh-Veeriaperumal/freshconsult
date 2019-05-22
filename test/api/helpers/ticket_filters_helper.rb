module TicketFiltersHelper
  def sample_filter_input_params(options = {})
    {
      name: options[:name] || Faker::Name.name,
      order_by: options[:order] || sort_field_options.sample,
      order_type: options[:order_type] || ApiConstants::ORDER_TYPE.sample,
      per_page: options[:per_page] || 30
    }.merge({
      query_hash: query_hash_queries(options)
    }.merge(visibility_pattern(options)))
  end

  def visibility_pattern(options = {})
    {
      visibility: {
        visibility: options[:visibility_id] || Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        group_id: options[:group_id] || 1
      }
    }
  end

  def query_hash_queries(_options = {})
    QueryHash.new(sample_filter_conditions[:data_hash]).to_json
  end

  def ticket_filter_show_pattern(filter)
    basic_pattern = {
      id: filter[:id],
      name: filter[:name]
    }
    if filter.is_a?(Helpdesk::Filters::CustomTicketFilter)
      basic_pattern.merge!(custom_filter_attributes(filter))
      basic_pattern[:visibility] = filter.accessible.attributes.slice('visibility', 'group_id', 'user_id')
      basic_pattern[:query_hash] = query_hash_pattern_output(filter.data[:data_hash])
    else
      basic_pattern[:default] = true
      basic_pattern[:hidden] = true if TicketsFilter.accessible_filters(TicketFilterConstants::HIDDEN_FILTERS).include?(filter[:id])
      basic_pattern[:order_by] = filter[:order_by] if filter[:order_by]
      basic_pattern[:order_type] = filter[:order_type] if filter[:order_type]
      if CustomFilterConstants::REMOVE_QUERY_HASH.exclude?(filter[:id])
        basic_pattern[:query_hash] = query_hash_pattern_output(filter[:query_hash])
      end
    end
    basic_pattern
  end

  def custom_filter_attributes(filter)
    {
      default: false,
      order_by: filter.data[:wf_order],
      order_type: filter.data[:wf_order_type],
      created_at: filter[:created_at].try(:utc).try(:iso8601),
      updated_at: filter[:updated_at].try(:utc).try(:iso8601),
      per_page: 30
    }
  end

  def query_hash_pattern_output(query_hash)
    QueryHash.new(query_hash).to_json
  end

  def default_filter_pattern(filter_name)
    filter = (TicketsFilter.default_visible_filters(filter_name).presence || TicketsFilter.default_hidden_filters(filter_name)).select { |f| f[:id] == filter_name.to_s }.first
    ticket_filter_show_pattern(filter)
  end

  def create_error_pattern(missing_fields)
    field_errors = missing_fields.map { |f| bad_request_error_pattern(f.to_s, :missing_field) }
    {
      description: 'Validation failed',
      errors: field_errors
    }
  end

  def ticket_filter_index_pattern(user = User.current)
    all_filters = []
    (all_custom_ticket_filters(user) + TicketsFilter.default_visible_filters + TicketsFilter.default_hidden_filters).compact.each do |filter|
      all_filters << ticket_filter_show_pattern(filter)
    end
    all_filters
  end

  def all_custom_ticket_filters(user = User.current)
    Account.current.ticket_filters.my_ticket_filters(user)
  end

  def sort_field_options
    TicketsFilter.api_sort_fields_options.map(&:first).map(&:to_s)
  end
end
