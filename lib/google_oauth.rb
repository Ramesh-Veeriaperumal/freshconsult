module GoogleOauth
	include Redis::RedisKeys
  include Redis::OthersRedis

	def create_user(account, name, email)
    user = account.users.new(:name => name, :email => email, :active => true)
    user.save!
    user
  end

  def create_auth(user, uid, account_id)
    user.authorizations.create(:provider => 'oauth',
                               :uid => uid,
                               :account_id => account_id) if user.authorizations.blank?
  end

  def set_redis_and_redirect(request_domain, email, domain_account, uid)
    set_redis_key_for_sso(request_domain, email, uid)
    redirect_url = construct_redirect_url(domain_account, request_domain, "oauth", uid)
    Rails.logger.info "GoogleOauth redirect_url #{redirect_url}"
    redirect_to redirect_url
  end

  def set_redis_key_for_sso(domain, email, uid)
    redis_oauth_key = GOOGLE_OAUTH_SSO % { :domain => domain , :uid => uid}
    set_others_redis_key(redis_oauth_key, email, 300) # key expires in 5*60 seconds (5 mins)
  end

  def construct_redirect_url(account, domain, type, uid)
    protocol = (account.ssl_enabled? || is_native_mobile?) ? "https" : "http"
    if type == "openid"
      url = "https://www.google.com/accounts/o8/site-xrds?hd="+domain
      redirect_url = protocol+"://" + account.host + "/auth/open_id?openid_url="+url
    elsif type == "oauth"
      redirect_url = portal_login_from_domain(account, domain, protocol, uid)
    end
    redirect_url
  end

  def portal_login_from_domain(account, domain, protocol, uid)
    if params[:state].present?
      redirect_url = protocol+"://"+requested_portal_url + "/sso/google_login?domain="+ domain + "&uid="+uid
      redirect_url = redirect_url + "&portal_url=" + requested_portal_url
    else
      redirect_url = protocol+"://"+account.host + "/sso/google_login?domain="+ domain + "&uid="+uid
    end
  end

  def choose_layout
    (["create_account_from_google", "marketplace_login",
      "associate_google_account", "associate_local_to_google",
      "create_account_google"].include?(action_name)) ? 'signup_google' : 'application'
  end

end