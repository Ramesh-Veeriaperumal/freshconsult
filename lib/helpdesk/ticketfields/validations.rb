module Helpdesk::Ticketfields::Validations
  include Helpdesk::Ticketfields::Constants

  def check_ticket_field_count
    field_data_group = custom_field_data.group_by { |c_f_d| c_f_d['type']}
    field_data_count_by_type = {
      text:    calculate_fields_count(field_data_group['paragraph']),
      number:  calculate_fields_count(field_data_group['number']),
      boolean: calculate_fields_count(field_data_group['checkbox']),
      decimal: calculate_fields_count(field_data_group['decimal']),
      date:    calculate_fields_count(field_data_group['date'])
    }.merge(feature_based_fields_count(field_data_group))

    error_str = ''
    max_count = max_allowed_count(field_data_group)

    field_data_count_by_type.each_key do |key|
      next unless field_data_count_by_type[key] > max_count[key]
      translate_key = if additional_fields_supported_type?(key) && denormalized_flexifields_enabled?
                        "#{key}_with_dn"
                      elsif ticket_field_limit_increase_enabled?
                        "#{key}_ticket_field_data"
                      else
                        key
                      end
      error_str << "#{I18n.t("flash.custom_fields.failure.#{translate_key}")} <br/>"
    end

    unless error_str.blank?
      flash[:error] = error_str.to_s.html_safe
      redirect_to :back and return
    end
  end

  def feature_based_fields_count(field_data_group)
    {}.tap do |h|
      dn_flexifield_enabled = denormalized_flexifields_enabled?
      h[:string] = calculate_string_fields_count(field_data_group, dn_flexifield_enabled)
      h[:dropdown] = calculate_dropdown_fields_count(field_data_group) if dn_flexifield_enabled
    end
  end

  def max_allowed_count(field_data_group)
    if denormalized_flexifields_enabled?
      ffs_slt_fields = calculate_ffs_string_fields_count(field_data_group['text'])
      dropdown_limit_with_dnf = ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_DROPDOWN_COUNT : FFS_LIMIT
      boolean_limit = ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_CHECKBOX_COUNT : CHECKBOX_FIELD_COUNT
      date_field_limit = ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_DATE_FIELD_COUNT : DATE_FIELD_COUNT
      number_field_limit = ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_NUMBER_COUNT : NUMBER_FIELD_COUNT
      dropdown_limit = dropdown_limit_with_dnf - ffs_slt_fields
      MAX_ALLOWED_COUNT_DN.dup.merge(
        dropdown: dropdown_limit, boolean: boolean_limit,
        number: number_field_limit, date: date_field_limit
      )
    else
      ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_COUNT.dup : MAX_ALLOWED_COUNT.dup
    end
  end

  def calculate_string_fields_count(field_data_group, dn_flexifield_enabled = false)
    count = calculate_fields_count(field_data_group['text']) + calculate_fields_count(field_data_group['encrypted_text'])
    count += calculate_dropdown_fields_count(field_data_group) unless dn_flexifield_enabled
    count
  end

  def calculate_dropdown_fields_count(field_data_group)
    calculate_fields_count(field_data_group['dropdown']) +
      (field_data_group['dropdown'] || []).sum { |f| f['action'].to_s != 'delete' ? calculate_fields_count(f['levels']) : 0 }
  end

  def calculate_fields_count(fields)
    (fields || []).count { |field| field['action'].to_s != 'delete' }
  end

  def calculate_ffs_string_fields_count(string_fields)
    # Count if action on a non denormalized_field(old string field) is not deleted or a create action when denormalized feature is not enabled
    (string_fields || []).count do |field|
      field['denormalized_field'] == false && field['action'].to_s != 'delete'
    end
  end

  def additional_fields_supported_type?(type)
    SERIALIZED_TYPES.include?(type.to_s)
  end
end
