module WidgetConcern
  extend ActiveSupport::Concern

  include WidgetAuthentication

  included do
    skip_before_filter :check_privilege
    before_filter :check_feature
    before_filter :validate_widget
    before_filter :widget_token_authentication
  end

  def validate_widget
    @widget_id = request.env['HTTP_X_WIDGET_ID']
    return render_request_error(:widget_id_not_given, 400) if @widget_id.blank?

    @client_id = request.env['HTTP_X_CLIENT_ID']
    return render_request_error(:cliend_id_not_given, 400) if @client_id.blank?

    @help_widget = current_account.help_widget_from_cache(@widget_id.to_i)
    render_request_error(:invalid_help_widget, 400, id: @widget_id) unless @help_widget
  end

  def fetch_portal
    @current_portal = current_account.portals.find_by_product_id(@help_widget.product_id) || @current_portal
  end

  def check_feature
    render_request_error(:require_feature, 403, feature: :help_widget) unless current_account.help_widget_enabled?
  end

  def add_attachments
    @item.attachments = current_account.attachments.where(id: @attachment_ids) if @attachment_ids.present?
  end

  def set_current_language
    if current_account.multilingual?
      Language.set_current(
        request_language: http_accept_language.language_region_compatible_from(I18n.available_locales),
        url_locale: params[:language]
      )
    end
    Language.fetch_from_primary({}).make_current unless Language.current?
  end

  def user_visibility
    vis_arr = [Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
    if User.current
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents] if User.current.agent?
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users] if User.current.agent? || User.current.has_company?
    end
    vis_arr
  end
end
