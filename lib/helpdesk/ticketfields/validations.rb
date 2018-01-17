module Helpdesk::Ticketfields::Validations

  MAX_ALLOWED_COUNT = { 
    :string => 80,
    :text => 10,
    :number => 20,
    :date => 10,
    :boolean => 10,
    :decimal => 10
  }

  def check_ticket_field_count
    field_data_group = custom_field_data.group_by { |c_f_d| c_f_d['type']}
    field_data_count_by_type = {
                        :text => calculate_fields_count(field_data_group['paragraph']),
                        :number => calculate_fields_count(field_data_group['number']),
                        :boolean => calculate_fields_count(field_data_group['checkbox']),
                        :decimal => calculate_fields_count(field_data_group['decimal']),
                        :date => calculate_fields_count(field_data_group['date'])
                      }
    
    error_str = if denormalized_flexifields_enabled?
      check_ticket_field_count_with_dn field_data_count_by_type, field_data_group
    else
      check_ticket_field_count_without_dn field_data_count_by_type, field_data_group
    end

    unless error_str.blank?
      flash[:error] = error_str.to_s.html_safe 
      redirect_to :back and return
    end
  end

  def check_ticket_field_count_with_dn field_data_count_by_type, field_data_group
    error_str = ''
    field_data_count_by_type.merge!({
      :string => calculate_fields_count(field_data_group['text']),
      :dropdown => calculate_dropdown_fields_count(field_data_group)
    })

    ffs_slt_fields = calculate_ffs_string_fields_count(field_data_group['text'])
    dropdown_limit = MAX_ALLOWED_COUNT[:string] - ffs_slt_fields
    max_allowed_count = MAX_ALLOWED_COUNT.merge({:string => FlexifieldConstants::SERIALIZED_SLT_FIELDS.length, :dropdown => dropdown_limit})
    
    field_data_count_by_type.keys.each do |key|
      if field_data_count_by_type[key] > max_allowed_count[key]
        translate_key = (key == :string) ? "#{key}_with_dn" : key
        error_str << "#{I18n.t("flash.custom_fields.failure.#{translate_key}")} <br/>"
      end
    end
    error_str
  end

  def check_ticket_field_count_without_dn field_data_count_by_type, field_data_group
    error_str = ''
    field_data_count_by_type.merge!({
      :string => calculate_string_fields_count(field_data_group),
    })
    
    field_data_count_by_type.keys.each do |key|
      if field_data_count_by_type[key] > MAX_ALLOWED_COUNT[key]
        error_str << "#{I18n.t("flash.custom_fields.failure.#{key}")} <br/>"
      end
    end
    error_str
  end

  def calculate_string_fields_count field_data_group
    calculate_dropdown_fields_count(field_data_group) + calculate_ffs_string_fields_count(field_data_group['text'])
  end

  def calculate_dropdown_fields_count field_data_group
    calculate_fields_count(field_data_group['dropdown']) + 
      (field_data_group['dropdown'] || []).sum { |f| f['action'].to_s != 'delete' ? calculate_fields_count(f['levels']) : 0 }
  end

  def calculate_ffs_string_fields_count string_fields
    # Count if action on a non denormalized_field(old string field) is not deleted or a create action when denormalized feature is not enabled
    (string_fields || []).count do |_field|
      ( _field['denormalized_field'] == false && _field['action'].to_s != 'delete') || (!denormalized_flexifields_enabled? && _field['action'].to_s == 'create')
    end
  end

  def calculate_fields_count fields
    (fields || []).count { |_field| _field['action'].to_s != 'delete' }
  end

end
