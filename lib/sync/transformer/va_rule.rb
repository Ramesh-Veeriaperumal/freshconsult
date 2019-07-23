module Sync::Transformer::VaRule
  include Sync::Transformer::Util
  FITER_DATA_NAME_MAPPINGS = {
    'responder_id' => 'User',
    'group_id' => 'Group',
    'tag_ids' => 'Helpdesk::Tag',
    'product_id' => 'Product',
    'business_hours_id' => 'BusinessCalendar',
    'internal_group_id' => 'Group',
    'internal_agent_id' => 'User'
  }.freeze
  STATUS_DATA_NAME_MAPPINGS = {
    'status' => 'Helpdesk::TicketStatus'
  }.freeze
  ACTION_DATA_NAME_MAPPINGS = {
    'responder_id' => 'User',
    'group_id' => 'Group',
    'add_watcher' => 'User',
    'send_email_to_group' => 'Group',
    'send_email_to_agent' => 'User',
    'send_email_to_requester' => '',
    'internal_group_id' => 'Group',
    'internal_agent_id' => 'User',
    'product_id' => 'Product'
  }.freeze

  def transform_va_rule_filter_data(data, mapping_table = {})
    iterator = data.is_a?(Hash) ? data[:conditions] || [] : data
    transform_condition_data_conditions(iterator, mapping_table)
    transform_performer_and_events(data, mapping_table) if data.is_a?(Hash)
    data
  end

  def transform_va_rule_condition_data(data, mapping_table = {})
    return data if data.blank? # supervisor case

    va_conditions = data.key?(:events) ? data[:conditions] : data
    transform_performer_and_events(data, mapping_table) if data[:performer].present?
    return data if va_conditions.blank? || va_conditions.first[1].blank? # conditions(new)

    if va_conditions.first[1][0].key?(:evaluate_on)
      transform_condition_data_conditions(va_conditions.first[1], mapping_table)
    else
      va_conditions.first[1].each do |set|
        set.each { |i| transform_condition_data_conditions(i[1], mapping_table) }
      end
    end
    data
  end

  def transform_va_rule_action_data(data, mapping_table = {})
    iterator = data
    iterator.each do |it|
      it.symbolize_keys!
      if it[:nested_rules].present?
        it[:category_name] = change_custom_field_name(it[:category_name])
        it[:nested_rules].each do |nested_rule|
          nested_rule[:name] = change_custom_field_name(nested_rule[:name])
        end
      elsif STATUS_DATA_NAME_MAPPINGS.keys.include?(it[:name])
        model_name = STATUS_DATA_NAME_MAPPINGS[it[:name]]
        it[:value] = apply_id_mapping(it[:value], get_mapping_data(model_name, mapping_table, 'status_id'), model_name)
      elsif ACTION_DATA_NAME_MAPPINGS.keys.include?(it[:name])
        value_key = ['send_email_to_group', 'send_email_to_agent'].include?(it[:name]) ? :email_to : :value
        it[value_key] = apply_id_mapping(it[value_key], get_mapping_data(ACTION_DATA_NAME_MAPPINGS[it[:name]], mapping_table)) if ACTION_DATA_NAME_MAPPINGS[it[:name]].present?
        it[:email_body] = transform_inline_attachment(it[:email_body], mapping_table) if it[:email_body].present?
      else
        it[:name] = change_custom_field_name(it[:name])
      end
    end
    data
  end

  def transform_va_rule_last_updated_by(data, mapping_table = {})
    apply_id_mapping(data, get_mapping_data(FITER_DATA_NAME_MAPPINGS['responder_id'], mapping_table))
  end

  private

    def transform_performer_and_events(data, mapping_table)
      if data[:performer].present? && data[:performer]['members'].present?
        data[:performer]['members'] = apply_id_mapping(data[:performer]['members'], get_mapping_data('User', mapping_table))
      end
      tranform_filter_data_events(data[:events], mapping_table)
    end

    def transform_condition_data_conditions(data, mapping_table)
      data.each do |it|
        it.symbolize_keys!
        case true
        when it[:nested_rules].present?
          transform_filter_data_nested_rules(it)
        when FITER_DATA_NAME_MAPPINGS.keys.include?(it[:name])
          it[:value] = apply_id_mapping(it[:value], get_mapping_data(FITER_DATA_NAME_MAPPINGS[it[:name]], mapping_table))
        when STATUS_DATA_NAME_MAPPINGS.keys.include?(it[:name])
          model_name = STATUS_DATA_NAME_MAPPINGS[it[:name]]
          it[:value] = apply_id_mapping(it[:value], get_mapping_data(model_name, mapping_table, 'status_id'), model_name)
        when it[:name] == 'created_at' && it[:business_hours_id].present?
          model_name = FITER_DATA_NAME_MAPPINGS['business_hours_id']
          it[:business_hours_id] = apply_id_mapping(it[:business_hours_id], get_mapping_data(model_name, mapping_table))
        else
          it[:name] = change_custom_field_name(it[:name])
        end
      end
    end

    def tranform_filter_data_events(data, mapping_table)
      data.each do |it|
        it.symbolize_keys!
        next unless (FITER_DATA_NAME_MAPPINGS.keys + STATUS_DATA_NAME_MAPPINGS.keys).include?(it[:name])
        [:from, :to].each do |value_key|
          if FITER_DATA_NAME_MAPPINGS.keys.include?(it[:name])
            it[value_key]  = apply_id_mapping(it[value_key], get_mapping_data(FITER_DATA_NAME_MAPPINGS[it[:name]], mapping_table))
          else
            model_name = STATUS_DATA_NAME_MAPPINGS[it[:name]]
            it[value_key]  = apply_id_mapping(it[value_key], get_mapping_data(model_name, mapping_table, 'status_id'), model_name)
          end
        end
      end
    end

    def transform_filter_data_nested_rules(data)
      data[:name] = change_custom_field_name(data[:name])
      data[:nested_rules].each do |nested_rule|
        nested_rule[:name] = change_custom_field_name(nested_rule[:name])
      end
    end
end
