module Search::Filters::EsQueryMethods
  COLUMN_MAPPING = {
    'helpdesk_schema_less_tickets.boolean_tc02' =>  'trashed',
    'owner_id'                                  =>  'company_id',
    'helpdesk_tags.id'                          =>  'tag_ids',
    'helpdesk_tags.name'                        =>  'tag_names',
    'helpdesk_subscriptions.user_id'            =>  'watchers',
    'helpdesk_schema_less_tickets.product_id'   =>  'product_id'
  }.freeze

  private

    # Loop and construct ES conditions from WF filter conditions
    def construct_conditions(es_wrapper, wf_conditions)
      wf_conditions.each do |field|
        cond_field = (COLUMN_MAPPING[field['condition']].presence || field['condition'].to_s).gsub(QueryHash::FLEXIFIELDS, '')
        cond_field = cond_field.gsub(QueryHash::TICKET_FIELD_DATA, '') if cond_field.include?(QueryHash::TICKET_FIELD_DATA)
        if Account.current.wf_comma_filter_fix_enabled?
          field_values = field['value'].is_a?(Array) ? field['value'] : field['value'].to_s.split(::FilterFactory::TicketFilterer::TEXT_DELIMITER)
        else
          field_values = field['value'].to_s.split(',')
        end
        es_wrapper.push(handle_field(cond_field, field_values)) if cond_field.present?
      end
    end

    def account_id_filter
      term_filter(:account_id, Account.current.id)
    end

    # Cache default: false
    def bool_filter(cond_block)
      { :bool => cond_block }
    end

    # Cache: always true
    def missing_filter(field_name)
      { :missing => { :field => field_name.to_s } }
    end

    # Default execution mode: Index
    # Cache default(index execution): true
    def range_filter(field_name, value_with_op)
      { :range => { field_name.to_s =>  value_with_op, :_cache => false } }
    end

    # Cache default: true
    def terms_filter(field_name, values)
      { :terms => { field_name.to_s => values, :_cache => false } }
    end

    # Cache default: true
    def term_filter(field_name, value)
      { :term => { field_name.to_s => value, :_cache => false } }
    end

    def terms_filter_any_agent(values)
      ["responder_id","internal_agent_id"].map { |field_name| terms_filter(field_name, values) }
    end

    def terms_filter_any_group(values)
      ["group_id","internal_group_id"].map { |field_name| terms_filter(field_name, values) }
    end

    def filtered_query(query_part={}, filter_part={})
      base = ({ :query => { :bool => {} } })
      base[:query][:bool].update(query_part) if query_part.present?
      base[:query][:bool].update(:filter => filter_part) if filter_part.present?
      base
    end

    def ids_filter ids
      { :ids => { values: ids } }
    end

    def multi_match_query(query, fields=[], operator=nil)
      {
        :multi_match => Hash.new.tap do |qparams|
          qparams[:query] = query
          qparams[:fields] = fields
          qparams[:operator] = operator if operator
        end
      }
    end

    def default_condition_block
      {
        :should   => [],
        :must     => [],
        :must_not => []
      }
    end
end
