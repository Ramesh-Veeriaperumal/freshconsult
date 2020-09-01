class Helpdesk::Ticketfields::PicklistValueTransformer::StringToId < Helpdesk::Ticketfields::PicklistValueTransformer::Base
  NONE_VALUE = '-1'.freeze

  def transform(picklist_value, flexifield_name)
    return if picklist_value.blank?

    picklist_value = picklist_value.downcase
    field = ticket_field_by_flexifield_name_hash[flexifield_name]
    picklist_value_mapping = picklist_ids_by_value(field)
    return if picklist_value_mapping.nil?

    if field.child_nested_field?
      base_val = picklist_value_mapping[picklist_value]
      return if base_val.nil?

      if @ticket
        if field.level == 3
          field, base_val = parent_field_value(field, base_val)
          return if base_val.nil?
        end
        _, base_val = parent_field_value(field, base_val)
      end
      base_val
    else
      picklist_value_mapping[picklist_value]
    end
  end

  def fetch_ids(values_list, ff_alias)
    if Account.current.wf_comma_filter_fix_enabled?
      values_list = values_list.is_a?(Array) ? values_list : values_list.to_s.split(::Wf::Filter::TEXT_DELIMITER)
    end
    values_list.collect do |value|
      value == NONE_VALUE ? value : transform(value, fetch_col_name(ff_alias))
    end
  end

  def modify_data_hash(data_hash)
    @nested_field_helper = NestedFieldCorrection.new
    parse_nested_fields(data_hash)
    data_hash.each do |con_hash|
      next unless con_hash['ff_name'].present? && con_hash['ff_name'] != 'default'
      if @nested_field_helper.column_name_map.key(con_hash['ff_name'])
        con_hash['value'] = handle_nested_field(con_hash)
      elsif dropdown_nested_field?(con_hash['ff_name'])
        if Account.current.wf_comma_filter_fix_enabled?
          con_hash['value'] = fetch_ids(con_hash['value'], con_hash['ff_name']).join(::Wf::Filter::TEXT_DELIMITER)
        else
          con_hash['value'] = fetch_ids(con_hash['value'].split(','), con_hash['ff_name']).join(',')
        end
      end
      con_hash['condition'].gsub!('flexifields.', 'ticket_field_data.')
    end
  end

  private

    def dropdown_nested_field?(name)
      fields_from_cache[name].present?
    end

    def fetch_col_name(ff_alias)
      fields_from_cache[ff_alias].column_name.presence || fields_from_cache[ff_alias].flexifield_def_entry.flexifield_name
    end

    def handle_nested_field(con_hash)
      field_parent_id = fetch_parent_id(con_hash)
      if Account.current.wf_comma_filter_fix_enabled?
        result = fetch_ids(con_hash['value'], con_hash['ff_name'])
      else
        result = fetch_ids([con_hash['value']], con_hash['ff_name'])
      end
      if result.first.is_a?(Hash)
        result = result.first
        nested_level = @nested_column_key_pair[field_parent_id].index(con_hash['value'])
        if nested_level == 1 # second level
          if Account.current.wf_comma_filter_fix_enabled?
            result[@nested_column_key_pair[field_parent_id][0][0].downcase]
          else
            result[@nested_column_key_pair[field_parent_id][0].downcase]
          end
        elsif nested_level == 2 # third level
          if Account.current.wf_comma_filter_fix_enabled?
            result[@nested_column_key_pair[field_parent_id][1][0].downcase][@nested_column_key_pair[field_parent_id][0][0].downcase]
          else
            result[@nested_column_key_pair[field_parent_id][1].downcase][@nested_column_key_pair[field_parent_id][0].downcase]
          end
        end
      else
        result.join(',')
      end
    end

    def parse_nested_fields(data_hash)
      @nested_column_key_pair = Hash.new { |h, k| h[k] = [] }
      data_hash.each do |con_hash|
        if @nested_field_helper.column_name_map.key(con_hash['ff_name'])
          field_parent_id = fetch_parent_id(con_hash)
          @nested_column_key_pair[field_parent_id].push << con_hash['value']
        end
      end
    end

    def fetch_parent_id(con_hash)
      ffs_col = @nested_field_helper.column_name_map.key(con_hash['ff_name'])
      @nested_field_helper.column_id_map[ffs_col]
    end

    def fields_from_cache
      @fields_from_cache ||= dropdown_nested_fields.each_with_object({}) do |field, f_hash|
        f_hash[field.name] = field unless field.is_default_field?
      end
    end

    def picklist_ids_by_value(field)
      mapping = ids_by_value_from_cache[field.picklist_ids_by_value_key]
      mapping.presence || field.picklist_ids_by_value_from_cache
    end

    def parent_field_value(ticket_field, base_val)
      parent_field = ticket_field.parent_field
      parent_value = (@ticket.custom_fields_hash.present? &&
                      @ticket.custom_fields_hash[parent_field.name].try(:downcase)) ||
                     (parent_field.try(:name) && @ticket.custom_field_value(parent_field.name).try(:downcase))
      [parent_field, base_val && base_val[parent_value]]
    end
end
