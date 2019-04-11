module SolutionConcern
  extend ActiveSupport::Concern

  include Cache::Memcache::Account

  def validate_language
    if params.key?(:language)
      permitted_languages = Account.current.supported_languages
      permitted_languages += [Account.current.language] unless create?
      invalid_language = true
      if !Account.current.multilingual?
        render_request_error(:require_feature, 404, feature: 'MultilingualFeature')
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

  def current_request_language
    Language.find_by_code(params[:language] || Account.current.language)
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
    current_account.solution_categories.where(parent_id: category_meta_ids, language_id: language_id)
  end
end
