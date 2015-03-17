class GoogleLoginController < AccountsController
	include GoogleLoginHelper
	include GoogleOauth

  around_filter :select_shard
  skip_before_filter :check_privilege
  before_filter :login_account, :only =>[:create_account_from_google]
  before_filter :ensure_proper_protocol

  def marketplace_login
    redirect_to construct_google_auth_url('', 'google_oauth2')
  end

  def google_gadget_login #endpoint given for app install in google_gadget
    redirect_to construct_google_auth_url('', 'google_gadget_oauth2')
  end

  def portal_login
    redirect_to construct_google_auth_url(current_account.full_domain, 'google_oauth2')
  end

  def create_account_from_google #return url endpoint for all google_apps
    params[:state].present? ? login_from_portal : login_from_marketplace
    if login_account.present?
      login_account.make_current
      activate_user_and_redirect
    end
  end

  private
    def select_shard(&block)
      account_domain_or_id = request.host
      if integrations_url?
        account_domain_or_id = actual_domain ||
          find_account_by_google_domain(request_domain)
      end
      Sharding.select_shard_of(account_domain_or_id || request.host) do
        yield
      end
    end

    def integrations_url?
      request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '') or
       (Rails.env.development? and
        request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '').gsub(/:3000/i,''))
    end

    def auth_hash
      @auth_hash ||= request.env['omniauth.auth'] || {}
    end

    def login_from_portal
      redirect_to "http://#{requested_portal_url}" and return if login_account.blank?
    end

    def requested_portal_url
      if params[:state].present?
        @portal_url ||= state_params['portal_url'] ? state_params['portal_url'][0].to_s : state_params['full_domain'][0].to_s
      elsif login_account
        login_account.full_domain
      else
        request.host
      end
    end

    def google_viewer_id_from_state
      if params[:state].present?
        google_viewer_id = state_params['gv_id'] ? state_params['gv_id'][0].to_s : nil
      else
        nil
      end
    end

    def login_from_marketplace
      create_account_user and return if login_account.nil?
    end

    def state_params
      if params[:state].present?
        @state_params ||= CGI.parse(params[:state])
      end
    end

    def actual_domain
      state_params && state_params['full_domain'][0].to_s
    end

    def login_account
      return @login_account if @login_account && @login_account.present?
      if params[:state].present?
        @login_account = Account.find_by_full_domain(state_params['full_domain'][0].to_s)
      elsif request_domain.present?
        account_id = find_account_by_google_domain(request_domain)
        @login_account = Account.find_by_id(account_id)
      end
    end

    def activate_user_and_redirect
      request_domain = requested_portal_url
      google_viewer_id = google_viewer_id_from_state
      if google_viewer_id.present? # Request is from Gadget.
        google_gadget_auth(google_viewer_id)
        render :text => @notice and return unless @gadget_error.nil?
      else # Request is not from Gadget.
        verify_domain_user # verify_domain_user creates a user and makes him active if the user is not present.
      end
      set_redis_and_redirect(request_domain, email, login_account, uid)
    end

end