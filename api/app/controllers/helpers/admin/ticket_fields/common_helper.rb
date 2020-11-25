module Admin::TicketFields::CommonHelper
  include Admin::TicketFieldConstants

  private

    def archive_data(field, data)
      if data[:archived].present?
        data.delete :archived
        field[:deleted] = true
      end
    end

    def delete_data(field, data)
      if data[:deleted].present?
        field.mark_for_destruction
        return true
      end
      false
    end

    def valid_data_type?(name, key, value, expected_type)
      return false if expected_type.blank?

      parent_expected_type, children_expected_type = *expected_type
      invalid_data_type("#{name}[#{key}]".intern, expected_type, :invalid) unless match_type?(value, parent_expected_type)
      invalid_data_type(:"#{name}[#{key}][:each]".intern, children_expected_type, :invalid) if children_expected_type && !match_children?(value, children_expected_type)
    end

    def validate_presence_of_data?(name, key, value)
      blank_value_for_attribute("#{name}[#{key}]".intern, key) if value.blank? && !value.is_a?(FalseClass)
    end

    def build_params(constant, param)
      constant.each_with_object({}) do |m, n|
        n[m[0]] = param[m[1]] unless param[m[1]].nil?
      end
    end

    def map_ticket_field_params(record, constant_attrs, requester_params)
      constant_attrs.each_with_object({}) do |field_param, mapping|
        mapping[field_param[0]] = if field_param[1] == :name
                                    field_name(requester_params[:label])
                                  elsif field_param[1] == :column_name
                                    avail_db_column(record)
                                  elsif field_param[1] == :ticket_form_id
                                    Account.current.ticket_field_def.id
                                  elsif field_param[1] == :flexifield_coltype
                                    column_type
                                  elsif field_param[1] == :position
                                    assign_ticket_field_position(requester_params, requester_params[field_param[1]])
                                  elsif TICKET_FIELD_PORTAL_PARAMS.key?(field_param[1])
                                    create? ? (requester_params[field_param[1]] || false) : requester_params[field_param[1]]
                                  else
                                    requester_params[field_param[1]]
                                  end
        mapping.delete(field_param[0]) if mapping[field_param[0]].nil?
        update_requester_params(record, mapping, field_param)
      end
    end

    def create_flexifield_entry(attrs)
      attrs[:position] ||= 1 # flexifield_order is mandatory
      Account.current.flexifield_def_entries.build(build_params(FLEXIFIELD_PARAMS, attrs))
    end

    def field_name(label)
      encrypted_field = cname_params[:type].in?(ENCRYPTED_FIELDS.stringify_keys.keys)
      existing_label = Helpdesk::TicketField.construct_label(label, encrypted_field)
      exist = current_account.all_ticket_fields_with_nested_fields_from_cache.any? { |tf| tf.name == "cf_#{existing_label}_#{current_account.id}" }
      Helpdesk::TicketField.field_name(label, current_account.id, exist, encrypted_field)
    end

    def avail_db_column(record)
      col_name = record.fetch_available_column(column_type)
      record.fetch_flexifield_columns[column_type] << col_name
      return custom_field_limit_exceeded(cname_params[:type]) if col_name.blank? # in case of field limit exceeded
      col_name
    end

    def column_type(type = cname_params[:type])
      FIELD_TYPE_TO_COL_TYPE_MAPPING[type.to_sym][0]
    end

    def assign_ticket_field_position(requester_params, value)
      return unless requester_params.key?(:position)

      @item.frontend_to_db_position(value) ||
        @item.account_ticket_field_position_mapping_from_cache[:ui_to_db][-1]
    end
end
