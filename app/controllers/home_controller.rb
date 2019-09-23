class HomeController < ApplicationController
  before_filter :redirect_to_mobile_url
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter { @hash_of_additional_params = { format: 'html' } }
  before_filter :set_content_scope, :set_mobile

  def index
    # redirect_to MOBILE_URL
    if can_redirect_to_mobile?
      redirect_to(mobile_welcome_path) && return
    elsif current_user && privilege?(:manage_tickets)
      redirect_to('/a/') && return if current_account.falcon_ui_enabled?(current_user)
      redirect_to(helpdesk_dashboard_path) && return
    else
      flash.keep(:notice)
      redirect_to(support_home_path(url_locale: current_user.language)) && return if
          current_account.multilingual? && current_user
      params.delete(:language) unless Language.find_by_code(params[:language])
      redirect_to(support_home_path(url_locale: params[:language])) && return
    end
    # redirect_to login_path and return unless (allowed_in_portal?(:open_solutions) || allowed_in_portal?(:open_forums))

    # @categories = current_portal.solution_categories.customer_categories if allowed_in_portal?(:open_solutions)
    # if allowed_in_portal?(:open_solutions)
    #   @categories = main_portal? ? current_portal.solution_categories.customer_categories : current_portal.solution_categories
    # end

    # if params[:format] == "mob"
    #   @user_session = current_account.user_sessions.new
    #   redirect_to login_path
    # end
  end

  protected

    def set_content_scope
      @content_scope = 'portal_'
      @content_scope = 'user_' if privilege?(:view_forums)
    end

    def can_redirect_to_mobile?
      current_user && mobile_agent? && !request.cookies['skip_mobile_app_download'] && current_user.agent?
    end
end
