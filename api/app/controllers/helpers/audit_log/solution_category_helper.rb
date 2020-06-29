module AuditLog::SolutionCategoryHelper
  include AuditLog::AuditLogHelper

  ALLOWED_MODEL_CHANGES = %i[name description].freeze

  def category_changes(_model_data, changes)
    response = []
    model_name = :category

    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)

      trans_key = translated_key(key, model_name)
      response.push description_properties(trans_key, value)
    end
    response
  end
end
