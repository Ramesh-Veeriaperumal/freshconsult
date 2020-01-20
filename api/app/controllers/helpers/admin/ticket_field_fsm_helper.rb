module Admin::TicketFieldFsmHelper
  include Admin::TicketFieldConstants

  def validate_fsm_params
    if request_params['section_mappings'].present?
      errors[:update_fsm] << :fsm_section_params_validation unless fsm_section?(tf) == true
    end
  end

  def validate_fsm_section
    errors[:section] << :fsm_section_modification if record.section_fields.present?
  end

  def fsm_section?(tf)
    section = tf.account_sections_from_cache.values.flatten.find { |sf| sf.label == SERVICE_TASK_SECTION }
    return nil if section.blank?
    section_id = section.id
    request_params['section_mappings'].each do |section_mapping|
      return true if section_mapping['section_id'] == section_id
    end
  end
end
