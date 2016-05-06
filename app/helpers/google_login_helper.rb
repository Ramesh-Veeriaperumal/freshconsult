module GoogleLoginHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def verify_domain_user account, nmobile=false
    domain_user = account.user_emails.user_for_email(email)
    if domain_user.blank?
      domain_user = create_user(account, name, email, nmobile)
    elsif !domain_user.active?
      make_user_active domain_user
    end
    create_auth(domain_user, uid, account.id)
  end

  def account_from_google_domain
    domain_name = google_domain
    domain_name.present? ? account_id_from_google_domain(domain_name) : nil
  end

  def set_redis_for_sso(key)
    redis_oauth_key = GOOGLE_OAUTH_SSO % {:random_key => key}
    set_others_redis_key(redis_oauth_key, uid, 300)
  end

  private

    def domain
      return URI.parse(@portal_url).host if @portal_url.present?
      Account.current.full_domain
    end

    def email
      @omniauth["info"]["email"]
    end

    def name
      @omniauth["info"]["name"]
    end

    def uid
      @omniauth["uid"]
    end

    def google_domain
      @omniauth["extra"].present? ? @omniauth["extra"]["raw_info"]["hd"] : nil
    end

    def google_domain_short
      "#{google_domain}".split(".")[0]
    end

    def account_id_from_google_domain(google_domain_name)
      g_domain = Integrations::GoogleRemoteAccount.where(:remote_id => "#{google_domain_name}").first
      g_domain.present? ? g_domain.account_id : nil
    end

    def create_user(account, name, email, nmobile)
      portal = account.portals.find_by_portal_url(requested_portal_url(nmobile))
      user = account.users.new
      user.active = true
      user.signup!(:user => {
        :name => name,
        :email => email,
        :language => portal.present? ? portal.language : account.language
      })
      user
    end

    def requested_portal_url nmobile
      if nmobile.present?
        @origin_account.full_domain
      else
        domain
      end
    end

    def create_auth(user, uid, account_id)
      user.authorizations.create(:provider => 'google',
                                 :uid => uid,
                                 :account_id => account_id) if user.authorizations.where(:provider => 'google', :uid => "#{uid}").blank?
    end

    def make_user_active user
      user.active = true
      user.save!
      user
    end

    def construct_protocol account, native_mobile_flag=false
      return "http" if Rails.env.development?
      return "https" if native_mobile_flag.present?
      account.url_protocol
    end

    def construct_params domain_arg, random_key
      param = "?domain=" + domain_arg + "&sso=" + random_key
      param = param + "&portal_url=" + domain_arg if @portal_url.present?
      param
    end

    def nmobile? param_var
      param_var[:format] == "nmobile"
    end

end
