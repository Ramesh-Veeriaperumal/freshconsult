module AuditLog::SolutionFolderHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::SolutionFolder

  ALLOWED_MODEL_CHANGES = %i[name description article_order solution_category_name visibility].freeze

  def folder_changes(_model_data, changes)
    response = []
    changes = readable_solution_folder_changes(changes)
    model_name = :folder

    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)

      trans_key = translated_key(key, model_name)
      response.push description_properties(trans_key, value)
    end
    response
  end
end
