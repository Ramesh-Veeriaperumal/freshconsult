module AuditLog::CompanyHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::Company

  ALLOWED_MODEL_CHANGES = [:name, :description, :note, :domains, :avatar, :health_score, :account_tier, :industry, :renewal_date].freeze

  def company_changes(_model_data, changes)
    response = []
    changes_with_custom_fields = readable_company_changes(changes)
    changes = changes_with_custom_fields[:model_changes]
    custom_fields_in_changes = changes_with_custom_fields[:custom_fields]
    model_name = :company
    changes.each_pair do |key, value|
      next unless (ALLOWED_MODEL_CHANGES.include? key) || (custom_fields_in_changes.include? key)

      trans_key = custom_fields_in_changes.include?(key) ? key.to_s : translated_key(key, model_name)
      value[0] = sanitize_audit_log_value(value[0].to_s) if check_bool_type(value[0]) || value[0].is_a?(String)
      value[1] = sanitize_audit_log_value(value[1].to_s) if check_bool_type(value[1]) || value[1].is_a?(String)
      response.push description_properties(trans_key, value)
    end
    response
  end
end
