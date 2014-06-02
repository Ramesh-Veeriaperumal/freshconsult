class GoogleLoginController < AccountsController
	include GoogleLoginHelper
	include GoogleOauth

  skip_before_filter :check_privilege
  before_filter :set_redis_key, :login_account, :only =>[:create_account_from_google]

  def marketplace_login
    redirect_to construct_google_auth_url('')
  end

  def portal_login
    redirect_to construct_google_auth_url(current_account.full_domain)
  end

  def create_account_from_google
    params[:state].present? ? login_from_portal : login_from_marketplace
    if login_account.present?
      login_account.make_current
      activate_user_and_redirect
    end
  end

  private
    def set_redis_key
      redis_key = GOOGLE_OAUTH_TOKEN % {:domain_name => request_domain}
      set_others_redis_key(redis_key, access_token)
    end

    def auth_hash
      @auth_hash ||= request.env['omniauth.auth'] || {}
    end

    def login_from_portal
      redirect_to requested_portal_url and return if login_account.nil?
    end

    def requested_portal_url
      if params[:state].present?
        @portal_url ||= state_params['portal_url']? state_params['portal_url'][0].to_s : state_params['full_domain'][0].to_s
      else
        login_account.full_domain
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

    def login_account
      return @login_account if defined?(@login_account)
      if params[:state].present?
        @login_account = Account.find_by_full_domain(state_params['full_domain'][0].to_s)
      elsif request_domain.present?
        account_id = find_account_by_google_domain(request_domain)
        @login_account = Account.find_by_id(account_id)
      end
    end

    def activate_user_and_redirect
      request_domain = requested_portal_url
      Sharding.select_shard_of(login_account.id) do
        verify_domain_user
        set_redis_and_redirect(request_domain, email, login_account, uid)
      end
    end

end