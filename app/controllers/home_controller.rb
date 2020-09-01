class HomeController < ApplicationController
  before_filter :add_security_headers, only: [:index_html]
  before_filter :redirect_to_mobile_url
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter { @hash_of_additional_params = { format: 'html' } }
  before_filter :set_content_scope, :set_mobile, only: [:index]
  skip_before_filter :check_account_state, :set_locale, :check_day_pass_usage, only: [:index_html]

  include Redis::OthersRedis
  include Redis::Keys::Others

  CONTENT_SECURITY_POLICY_AGENT_PORTAL_LOCAL_CACHE = 'CONTENT_SECURITY_POLICY_AGENT_PORTAL_LOCAL_CACHE'.freeze
  CSP_DIRECTIVES = {
    production: "default-src 'self'; script-src https://*.cloudfront.net cdn.headwayapp.co *.freshcloud.io https://assets.freshdesk.com https://cdn.heapanalytics.com ; style-src https://wchat.freshchat.com; img-src https://*.cloudfront.net https://heapanalytics.com; connect-src https://*.freshworksapi.com https://support.freshdesk.com; report-uri /api/_/cspreports",
    staging: "default-src 'self'; script-src https://*.cloudfront.net cdn.headwayapp.co *.freshcloud.io https://assets.freshpo.com https://cdn.heapanalytics.com; style-src https://wchat.freshchat.com; img-src https://*.cloudfront.net https://heapanalytics.com; connect-src https://*.freshworksapi.com https://*.freshpo.com; report-uri /api/_/cspreports"
  }.freeze
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

  def index_html
    render text: Assets::IndexPage.html_content, content_type: 'text/html'
  end

  def add_security_headers
    response.headers['Content-Security-Policy-Report-Only'] = csp_policy if Account.current.launched?(:csp_reports)
  end

  def csp_policy
    (Rails.cache.fetch(CONTENT_SECURITY_POLICY_AGENT_PORTAL_LOCAL_CACHE, race_condition_ttl: 10.seconds, expires_in: 15.minutes) do
      get_others_redis_key(CONTENT_SECURITY_POLICY_AGENT_PORTAL)
    end).presence || CSP_DIRECTIVES[:"#{Rails.env}"]
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
