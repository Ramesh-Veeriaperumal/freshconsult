module AuditLog::SolutionArticleHelper
  include AuditLog::AuditLogHelper
  include AuditLog::Translators::SolutionArticle

  ALLOWED_MODEL_CHANGES = %i[title description status tags agent_name solution_folder_name approval_status reset_ratings].freeze
  NESTED_DESCRIPTION_FIELDS = %i[tags].freeze

  def article_changes(_model_data, changes)
    response = []
    changes = readable_solution_article_changes(changes)
    model_name = :article
    changes.each_pair do |key, value|
      next unless ALLOWED_MODEL_CHANGES.include?(key)

      trans_key = translated_key(key, model_name)
      response.push NESTED_DESCRIPTION_FIELDS.include?(key) ? nested_description(trans_key, value, :article) : description_properties(trans_key, value)
    end
    response
  end
end
