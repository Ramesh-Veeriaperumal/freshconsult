module SolutionConcern
  extend ActiveSupport::Concern

  def validate_language
    if params.key?(:language)
      permitted_languages = allowed_languages
      permitted_languages -= [Account.current.language] if create?

      if !Account.current.multilingual?
        render_request_error :require_feature_to_suppport_the_request, 404, feature: 'EnableMultilingualFeature'
        return false
      elsif destroy?
        errors = [[:language, :invalid_field]]
        render_errors errors
      elsif permitted_languages.exclude?(params[:language])
        errors = [[:language, :not_included]]
        render_errors errors, list: permitted_languages.join(', ')
      end
      return false if errors
    end
    @lang_id = current_request_language.id
  end

  def allowed_languages
    @allowed_languages ||= [Account.current.language] + Account.current.supported_languages
  end

  def current_request_language
    Language.find_by_code(params[:language] || Account.current.language)
  end
end
