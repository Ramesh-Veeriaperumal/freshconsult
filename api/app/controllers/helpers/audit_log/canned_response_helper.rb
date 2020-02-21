module AuditLog::CannedResponseHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::CannedResponseTranslate

  ALLOWED_MODEL_CHANGES = [:title, :content_html, :folder_id, :access_type, :group_ids].freeze
  ALLOWED_NESTED_DESCRIPTIONS = [:attachments, :group_ids].freeze

  def canned_response_changes(_model_data, changes)
    response = []
    changes = readable_canned_response_changes(changes)
    model_name = :canned_response
    changes.each_pair do |key, value|
      next unless (ALLOWED_MODEL_CHANGES + ALLOWED_NESTED_DESCRIPTIONS).include?(key)

      trans_key = translated_key(key, model_name)
      value = sanitize_canned_response(value) if key == :title
      response << if ALLOWED_NESTED_DESCRIPTIONS.include?(key)
                    nested_description(trans_key, value, model_name)
                  else
                    description_properties(trans_key, value)
                  end
    end
    response
  end

  def sanitize_canned_response(value)
    if value.is_a?(Array)
      value[0]  = sanitize_audit_log_value(value[0])
      value[1]  = sanitize_audit_log_value(value[1])
    end
    value
  end
end
