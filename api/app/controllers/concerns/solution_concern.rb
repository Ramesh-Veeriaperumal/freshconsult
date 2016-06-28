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
        log_and_render_404
        return false
      elsif permitted_languages.exclude?(params[:language])
        render_request_error :language_not_allowed, 404, code: params[:language], list: permitted_languages.join(', ')
        return false
      end
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
