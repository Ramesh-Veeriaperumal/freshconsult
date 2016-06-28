module SolutionConcern
  extend ActiveSupport::Concern

  def validate_language
    if params.key?(:language)
      permitted_languages = Account.current.supported_languages
      permitted_languages += [Account.current.language] unless create?
      invalid_language = true
      if !Account.current.multilingual?
        render_request_error(:require_feature_to_suppport_the_request, 404, feature: 'EnableMultilingualFeature')
      elsif destroy?
        log_and_render_404
      elsif permitted_languages.exclude?(params[:language])
        render_request_error(:language_not_allowed, 404, code: params[:language], list: permitted_languages.sort.join(', '))
      else
        invalid_language = false
      end
      return false if invalid_language
    end
    @lang_id = current_request_language.id
  end

  def current_request_language
    Language.find_by_code(params[:language] || Account.current.language)
  end
end
