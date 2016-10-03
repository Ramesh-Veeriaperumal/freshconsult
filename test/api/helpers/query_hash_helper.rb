# ['roles_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module QueryHashHelper

  VALID_QUERY_TYPES = [:default, :custom_field]
  SPAM_CONDITION = { 'condition' => 'spam', 'operator' => 'is', 'value' => false }
  DELETED_CONDITION = { 'condition' => 'deleted', 'operator' => 'is', 'value' => false }

  def sample_filter_conditions
    {
      data_hash: [
        { "condition"=>"responder_id", "operator"=>"is_in", "ff_name"=>"default", "value"=>"0,-1" },
        { "condition"=>"group_id", "operator"=>"is_in", "ff_name"=>"default", "value"=>"0,3" },
        { "condition"=>"status", "operator"=>"is_in", "ff_name"=>"default", "value"=>"2" },
        { "condition"=>"created_at", "operator"=>"is_greater_than", "ff_name"=>"default", "value"=>"13 Sep 2016 - 23 Feb 2016" },
      ],
      wf_model: "Helpdesk::Ticket",
      wf_order: "created_at",
      wf_order_type: "desc", 
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
          user_id: User.current.id
        }
      }
    }
  end

  def create_filter(custom_field = nil)
    wf_filter_params = sample_filter_conditions
    if custom_field
      condition = cf_query_hash(custom_field)
      wf_filter_params[:data_hash] << condition
    end
    params = { filter_name: Faker::Name.name }.merge(wf_filter_params)
    wf_filter = Helpdesk::Filters::CustomTicketFilter.deserialize_from_params(params)
    wf_filter.visibility = params[:custom_ticket_filter][:visibility]
    wf_filter.save
    wf_filter
  end

  def cf_condition(field_alias, field_name, value)
    {
      'condition' => "flexifields.#{field_name}",
      'operator' => 'is_in',
      'ff_name' => field_alias,
      'value' => value
    }
  end

  def cf_query_hash(custom_field = @custom_field)
    fde = @custom_field.flexifield_def_entry
    cf_condition(fde.flexifield_alias, fde.flexifield_name, @custom_field.picklist_values.first.value)
  end

  def not_contain_spam_deleted(query_hash)
    query_hash.each do |query|
      return false if ['spam', 'deleted'].include?(query['condition'])
    end
    true
  end

  def contains_custom_field_condition(query_hash, custom_field, output_format = true)
    query_hash.each do |query|
      if output_format && query['type'] == 'custom_field' && query['condition'] == cf_display_name(custom_field.name)
        return true
      elsif !output_format && is_flexi_field?(query) && query['ff_name'] == custom_field.name
        return true
      end
    end
    false
  end

  def is_flexi_field?(query)
      query['ff_name'] != 'default' && query['condition'].include?('flexifields.')
    end

  def sample_created_at_input_condition(options = {})
    [
      {
        'condition' => 'created_at',
        'operator' => 'is_greater_than',
        'type' => 'default',
        'value' => {
          'from' => options[:from] || (Time.zone.now - 1.month).iso8601,
          'to' => options[:to] || Time.zone.now.iso8601
        }
      }
    ]
  end

  def response_query_created_at_pattern(options = {})
    [
      {
        'condition' => 'created_at',
        'operator' => 'is_greater_than',
        'type' => 'default',
        'value' => {
          'from' => options[:from] || %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\d(Z|\+\d\d:\d\d)$},
          'to' => options[:to] || %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\d(Z|\+\d\d:\d\d)$}
        }
      }
    ]
  end

  def system_query_created_at_pattern(options = {})
    [
      {
        'condition' => 'created_at',
        'operator' => 'is_greater_than',
        'ff_name' => 'default',
        'value' => options[:time] || %r{^(\d{2}\s\w{3}\s\d{4})\s-\s(\d{2}\s\w{3}\s\d{4})$}
      }
    ] + [SPAM_CONDITION, DELETED_CONDITION]
  end

  def cf_display_name(name)
    name[0..(-Account.current.id.to_s.length - 2)]
  end

  def system_format_query_check(query)
    match_custom_json(query, system_basic_pattern(query))
  end

  def basic_query_pattern(params)
    {
      'condition' => params['condition'],
      'operator' => params['operator'],
      'value' => params['value']
    }
  end

  def system_basic_pattern(query)
    if ['spam', 'deleted'].include?(query['condition'])
      basic_query_pattern(query)
    else
      basic_query_pattern(query).merge({ 'ff_name' => query['ff_name'] })
    end
  end

  def output_format_query_check(query)
    match_custom_json(query, output_basic_pattern(query))
  end

  def output_basic_pattern(query)
    basic_query_pattern(query).merge({ 'type' => query['type'] })
  end

end
