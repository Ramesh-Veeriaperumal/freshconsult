module SolutionConcern
  extend ActiveSupport::Concern

  include Cache::Memcache::Account

  def validate_language(allow_destroy = false)
    @permitted_languages ||= fetch_permitted_languages
    if params.key?(:language)
      invalid_language = true
      if !insert_solution_action? && !Account.current.multilingual? && params[:language] != Account.current.language && !allow_kb_language_fallback?
        render_request_error(:require_feature, 404, feature: 'MultilingualFeature')
      elsif destroy? && !allow_destroy
        log_and_render_404
      elsif @permitted_languages.exclude?(params[:language]) && !allow_kb_language_fallback?
        render_request_error(:language_not_allowed, 404, code: params[:language], list: @permitted_languages.sort.join(', '))
      else
        invalid_language = false
      end
      return false if invalid_language
    end
    @lang_code = current_request_language.to_key
    @lang_id = current_request_language.id
  end

  def validate_portal_id
    errors[:portal_id] << :invalid_portal_id if Account.current.portals.where(id: @portal_id).blank?
  end

  def solution_portal
    @solution_portal ||= begin
      current_account.portals.where(id: params[:portal_id]).first if params.key?(:portal_id)
    end
  end

  def solutions_scoper
    solution_portal || current_account
  end

  def public_api?(version)
    version == 'v2'
  end

  def transform_platform_params(platform_params)
    SolutionConstants::PLATFORM_TYPES.map { |platform| [platform, platform_params.include?(platform)] }.to_h
  end

  def current_request_language
    @permitted_languages ||= fetch_permitted_languages
    if allow_kb_language_fallback? && @permitted_languages.exclude?(params[:language]) && params.key?(:language)
      splitted_language = params[:language].split('-').first
      @permitted_languages.include?(splitted_language) ? Language.find_by_code(splitted_language) : Language.find_by_code(Account.current.language)
    else
      Language.find_by_code(params[:language] || Account.current.language)
    end
  end

  def secondary_language?
    Language.for_current_account != current_request_language
  end

  def render_solution_item_errors
    if @item.errors.any?
      render_custom_errors
    elsif @item.parent.errors.any?
      render_custom_errors @item.parent
    end
  end

  def fetch_unassociated_categories(language_id)
    category_meta_ids = unassociated_categories_from_cache
    Account.current.solution_categories.where(parent_id: category_meta_ids, language_id: language_id)
  end

  def insert_solution_action?
    params[:controller] == SolutionConstants::ARTICLES_PRIVATE_CONTROLLER && SolutionConstants::INSERT_SOLUTION_ACTIONS.include?(params[:action])
  end

  def allow_kb_language_fallback?
    params.key?(:allow_language_fallback) && params[:allow_language_fallback] && get_request?
  end

  def boolean_param?(key)
    params[key].present? && (params[key] == "true" || params[key] == "false")
  end

  def fetch_permitted_languages
    permitted_languages = Account.current.supported_languages
    permitted_languages += [Account.current.language] unless create?
    permitted_languages
  end
end
