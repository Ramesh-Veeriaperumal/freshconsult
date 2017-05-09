module Reports::ScheduledExport::Filters
  include Va::Constants
  
  NESTED_FIELD = "nested_field"
  DROPDOWN = "dropdown"

  def ticket_filters
    filter = default_filters + conditional_filters + custom_filters
  end

  def default_filters
    [
      { :name => -1, :value => t('click_to_select_filter') },
      { :name => "responder_id", :value => I18n.t('ticket.agent'), :domtype => dropdown_domtype,
        :operatortype => "object_id", :choices => @agents },
      { :name => "group_id", :value => I18n.t('ticket.group'), :domtype => dropdown_domtype,
        :operatortype => "object_id", :choices => @groups },
      { :name => "status", :value => t('ticket.status'), :domtype => dropdown_domtype, 
        :choices => Helpdesk::TicketStatus.status_names(current_account), :operatortype => "choicelist"},
      { :name => "priority", :value => t('ticket.priority'), :domtype => dropdown_domtype, 
        :choices => TicketConstants.priority_list.sort, :operatortype => "choicelist" },
      { :name => "ticket_type", :value => t('ticket.type'), :domtype => dropdown_domtype, 
        :choices => ticket_type_values_with_none, 
        :operatortype => "choicelist" },
      { :name => "source", :value => t('ticket.source'), :domtype => dropdown_domtype, 
        :choices => TicketConstants.source_list.sort, :operatortype => "choicelist" },
      { :name => "tag_names", :value => t('ticket.tag_condition'), :domtype => "autocomplete_multiple", 
        :data_url => tags_search_autocomplete_index_path, :operatortype => "choicelist",
        :autocomplete_choices => @tag_hash },
      { :name => "requester_id", :value => t('ticket.requester'), :domtype => "autocomplete_multiple_with_id", 
        :data_url => requesters_search_autocomplete_index_path, :operatortype => "choicelist",
        :autocomplete_choices => @requesters },
    ]
  end

  def conditional_filters
    [
      { :name => "internal_agent_id", :value => I18n.t('ticket.internal_agent'), :domtype => dropdown_domtype,
        :operatortype => "object_id", :choices => @internal_agents, :condition => allow_shared_ownership_fields? },
      { :name => "internal_group_id", :value => I18n.t('ticket.internal_group'), :domtype => dropdown_domtype,
        :operatortype => "object_id", :choices => @internal_groups, :condition => allow_shared_ownership_fields? },
      { :name => "product_id", :value => t('admin.products.product_label_msg'), :domtype => dropdown_domtype, 
        :choices => none_option+products, :operatortype => "choicelist",
        :condition => multi_product_account? },
    ].select{ |filter| filter.fetch(:condition, true) }  
  end

  def custom_filters
    filter = []
    cf = current_account.ticket_fields.custom_fields
    unless cf.blank?
      filter.push({ 
        :name => -1,
        :value => t('click_to_select_filter')
      })
      cf.each do |field|
        filter.push({
         :id            => field.id,
         :name          => field.name,
         :value         => field.label,
         :field_type    => field.field_type,
         :domtype       => domtype(field),
         :choices       => field_choices(field),
         :action        => "set_custom_field",
         :operatortype  => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
         :nested_fields => nested_fields(field)
        }) if ((field.field_type == NESTED_FIELD) || (field.flexifield_def_entry.flexifield_coltype == DROPDOWN))
      end
    end
    filter
  end

  def domtype field
    if field.field_type == NESTED_FIELD
      NESTED_FIELD
    elsif field.flexifield_def_entry.flexifield_coltype == DROPDOWN
      dropdown_domtype
    else
      field.flexifield_def_entry.flexifield_coltype
    end
  end

  def field_choices field
    nested_special_case = [['--', t('any_val.any_value')], ['', t('none')]]
    
    if field.field_type == NESTED_FIELD
      field.nested_choices_with_special_case nested_special_case
    else
      none_option+field.picklist_values.collect { |c| [c.value, c.value ] }
    end
  end

  def dropdown_domtype
    "multiple_select"
  end

  def set_nested_fields_data(data)
    nested_fields_data = []
    data.each do |f|
      if f['nested_rules']
        f['nested_rules'] = (ActiveSupport::JSON.decode f['nested_rules'])
        nested_rules = Marshal.load(Marshal.dump(f['nested_rules']))
        nested_rules.each do |nested_field_hash|
          nested_field_hash["operator"] = f["operator"]
          nested_fields_data.push(nested_field_hash)
        end
      end
      f['value'] = f['value'].split(',') if f['value'].present? && f['value'].is_a?(String)
    end
    data.push(*nested_fields_data)
    data.delete_if { |d| d['value'].eql?('--') }
  end

  def ticket_type_values_with_none
    [['', t('none')]]+current_account.ticket_types_from_cache.collect { |c| [ c.value, c.value ] }
  end

  def nested_fields ticket_field
    nestedfields = { :subcategory => "", :items => "" }
    if ticket_field.field_type == NESTED_FIELD
      ticket_field.nested_ticket_fields.each do |field|
        nestedfields[(field.level == 2) ? :subcategory : :items] = { :name => field.field_name, :label => field.label }
      end
    end
    nestedfields
  end

  def none_option
    [['', t('none')]]
  end

  def agents_list_from_cache
    @agents_list ||= current_account.agents_details_from_cache.collect { |au| [au.id, CGI.escapeHTML(au.name)] }
  end

  def groups_list_from_cache
    @groups_list ||= current_account.groups_from_cache.sort_by(&:name).collect { |g| [g.id, CGI.escapeHTML(g.name)]}
  end

  def allow_shared_ownership_fields?
    current_account.shared_ownership_enabled?
  end

  def multi_product_account?
    current_account.multi_product_enabled?
  end

  def products
    current_account.products.collect {|p| [p.id, p.name]}
  end

  def transform_fields_hash field_hash, field_data
    field_hash && field_hash.each do |field|
      field[:selected] = (field_data[field[:value]].present? ? true : false)
      # nested_fields
      if field.has_key?(:levels)
        field[:levels].each do |levels_field|
          levels_field[:selected] = (field_data[levels_field[:name]].present? ? true : false)
        end
      end
    end
  end 
end
