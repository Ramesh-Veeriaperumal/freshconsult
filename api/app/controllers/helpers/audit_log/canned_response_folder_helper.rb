module AuditLog::CannedResponseFolderHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::CannedResponseFolder

  ALLOWED_MODEL_CHANGES = [:name].freeze

  def canned_response_folder_changes(_model_data, changes)
    response = []
    changes = readable_canned_response_folder_changes(changes)
    model_name = :canned_response_folder
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)

      trans_key = translated_key(key, model_name)
      response.push description_properties(trans_key, value)
    end
    response
  end
end
