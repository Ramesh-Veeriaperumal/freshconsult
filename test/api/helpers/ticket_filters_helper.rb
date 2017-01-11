module TicketFiltersHelper

  def sample_filter_input_params(options = {})
    {
      name: options[:name] || Faker::Name.name, 
      order: options[:order] || ApiTicketConstants::ORDER_BY.sample,
      order_type: options[:order_type] || ApiTicketConstants::ORDER_TYPE.sample,
      per_page: options[:per_page] || 30,
    }.merge( { 
        query_hash: query_hash_queries(options)
      }.merge(visibility_pattern(options))
    )
  end

  def visibility_pattern(options = {})
    {
      visibility: {
        visibility: options[:visibility_id] || Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        group_id: options[:group_id] || 1
      }
    }
  end

  def query_hash_queries(options = {})
    QueryHash.new(sample_filter_conditions[:data_hash]).to_json
  end

  def get_default_visible_filters
    TicketsFilter.default_views.collect do |filter|
      if filter[:id].eql?('raised_by_me')
        filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter.new.raised_by_me_filter)
      elsif CustomFilterConstants::REMOVE_QUERY_HASH.include?(filter[:id])
        filter
      else
        filter.merge(query_hash: Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[filter[:id]])
      end
    end
  end

  def get_default_hidden_filters
    hidden_filter_names.collect do |filter|
      {
        id: filter, 
        name: I18n.t("helpdesk.tickets.views.#{filter}"), 
        default: true,
        hidden: true,
        query_hash: filter.eql?('on_hold') ? Helpdesk::Filters::CustomTicketFilter.new.on_hold_filter : Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[filter]
      }
    end
  end

  def hidden_filter_names
    TicketFilterConstants::HIDDEN_FILTERS - (Account.current.sla_management_enabled? ? [] : ['overdue', 'due_today'])
  end

  def ticket_filter_show_pattern(filter)
    basic_pattern = {
      id: filter[:id],
      name: filter[:name]
    }
    if filter.is_a?(Helpdesk::Filters::CustomTicketFilter)
      basic_pattern.merge!(custom_filter_attributes(filter)) 
      basic_pattern.merge!(query_hash: query_hash_pattern_output(filter.data[:data_hash]))
    else
      basic_pattern.merge!(default: true)
      basic_pattern.merge!(hidden: true) if hidden_filter_names.include?(filter[:id])
      if !CustomFilterConstants::REMOVE_QUERY_HASH.include?(filter[:id])
        basic_pattern.merge!(query_hash: query_hash_pattern_output(filter[:query_hash]))
      end
    end
    basic_pattern
  end

  def custom_filter_attributes(filter)
    {
      default: false,
      order: filter.data[:wf_order],
      order_type: filter.data[:wf_order_type],
      per_page: 30
    }
  end

  def query_hash_pattern_output(query_hash)
    QueryHash.new(query_hash).to_json
  end

  def default_filter_pattern(filter_name)
    filter = (get_default_visible_filters + get_default_hidden_filters).select { |f| f[:id] == filter_name.to_s }.first
    ticket_filter_show_pattern(filter)
  end

  def create_error_pattern(missing_fields)
    field_errors = missing_fields.map {|f| bad_request_error_pattern(f.to_s, :missing_field) }
    {
      description: 'Validation failed',
      errors: field_errors
    }
  end

  def ticket_filter_index_pattern
    all_filters = []
    (Account.current.ticket_filters + get_default_visible_filters + get_default_hidden_filters).compact.each do |filter|
      all_filters << ticket_filter_show_pattern(filter)
    end
    all_filters
  end

end