module Admin::AdvancedTicketing::FieldServiceManagement
  module CustomFieldValidator
    include Helpdesk::Ticketfields::Constants
    include Helpdesk::Ticketfields::Validations
    include Helpdesk::Ticketfields::ControllerMethods
    include Admin::AdvancedTicketing::FieldServiceManagement::Constant

    def custom_fields_available?
      new_custom_fields_count = denormalized_flexifields_enabled? ? DENORMOLIZED_CUSTOM_FIELDS_COUNT : NORMAL_CUSTOM_FIELDS_COUNT

      field_data_group = custom_fields_data.group_by { |c_f_d| c_f_d['type'] }
      field_data_count_by_type = {
        text:    calculate_fields_count(field_data_group['paragraph']),
        number:  calculate_fields_count(field_data_group['number']),
        boolean: calculate_fields_count(field_data_group['checkbox']),
        decimal: calculate_fields_count(field_data_group['decimal']),
        date:    calculate_fields_count(field_data_group['date'])
      }.merge(feature_based_fields_count(field_data_group))

      max_count = max_allowed_count(field_data_group)

      new_field_data_count = add_new_custom_fields_count(field_data_count_by_type, new_custom_fields_count)
      new_field_data_count.try(:each) do |key, _|
        max_value = key == :date_time ?  max_count[:date] : max_count[key]
        new_field_data_count[key] < max_value
      end
    end

    def custom_fields_data
      fields = Account.current.ticket_fields_including_nested_fields
      custom_fields = fields.reject { |f_d| f_d[:field_type].include?('default_') }
      field_types = Hash[Helpdesk::TicketField::CUSTOM_FIELD_PROPS.collect { |k, v| [k.to_s, v[:dom_type].to_s] }]
      field_types['custom_dropdown'] = 'dropdown'

      custom_fields.map do |field|
        {
          'type' => field_types[field.field_type],
          'denormalized_field' => denormalized_field?(field.column_name),
          'levels' => field.levels
        }
      end
    end

    def add_new_custom_fields_count(field_data_count_by_type, new_custom_fields_count)
      new_custom_fields_count.each do |k, v|
        existing_field_count = field_data_count_by_type[k].presence || 0
        field_data_count_by_type[k] = existing_field_count + v
      end
      field_data_count_by_type
    end

    def denormalized_field?(column_name)
      !(CustomFieldsController::FLEXIFIELD_PREFIXES.any? { |col_prefix| column_name.to_s.include?(col_prefix) })
    end

    def denormalized_flexifields_enabled?
      Account.current.denormalized_flexifields_enabled?
    end
  end
end
