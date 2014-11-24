module GoogleLoginHelper
  include Redis::RedisKeys

  def uid
    auth_hash['uid']
  end

  def name
    auth_hash['info']['name']
  end

  def email
    auth_hash['info']['email']
  end

  def access_token
    auth_hash_credentials = auth_hash['credentials']
    @access_token ||= auth_hash_credentials.token
  end

  def request_domain
    return @request_domain if @request_domain.present?
    if auth_hash['extra'].present?
      @request_domain = auth_hash['extra']['raw_info']['hd']
    else
      @request_domain = params[:state]
    end
  end

  def construct_google_auth_url(portal_url, provider_key_name)
    oauth_keys = Integrations::OauthHelper::get_oauth_keys
    app_name = google_app_name(provider_key_name, oauth_keys)
    auth_url = "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=" << consumer_token(provider_key_name, oauth_keys) << callback_url(app_name) << scopes(provider_key_name, oauth_keys) << options_name(app_name)
    if portal_url.present?
      auth_url = auth_url << '&state=full_domain%3D' << current_account.full_domain << '%26portal_url%3D'
      if current_portal.portal_url.present?
        auth_url = auth_url << current_portal.portal_url
      else
        auth_url = auth_url << current_account.full_domain
      end
    end
    auth_url
  end

  def find_account_by_google_domain(google_domain_name)
    unless google_domain_name.blank?
      account_id = nil
      google_domain = GoogleDomain.find_by_domain(google_domain_name)
      unless google_domain.blank?
        account_id = google_domain.account_id
      end
      account_id
    end
  end

  def create_account_user
    if request_domain.present?
      @account  = Account.new(:domain => request_domain.split(".")[0],
                              :name => name, :google_domain => request_domain)
      @user = @account.users.new(:email => email, :name => name) unless request.env['omniauth.auth'].blank?
      @uid = uid
      render 'google_signup/signup_google' and return
    else
      flash.now[:error] = t(:'flash.general.access_denied')
      render 'google_signup/signup_google_error' and return
    end
  end

  def verify_domain_user
    domain_user = login_account.all_users.find_by_email(email)
    if domain_user.blank?
      domain_user = create_user(login_account, name, email)
    elsif !domain_user.active?
      make_user_active domain_user
    end
    create_auth(domain_user, uid, login_account.id)
  end

  def google_gadget_auth google_viewer_id_hash
    domain_user = login_account.all_users.find_by_email(email)
    verify_gadget_user(domain_user)
    verify_gadget_viewer_id(google_viewer_id_hash, domain_user) unless @gadget_error.present?
    # If the user is also an agent and no OAuth entry in authrizations table then create one.
    create_auth(domain_user, uid, login_account.id) unless @gadget_error.present?
  end

  private
    def consumer_token(provider_key_name, oauth_keys)
      consumer_token = oauth_keys["#{provider_key_name}"]['consumer_token']
    end

    def callback_url(app_name)
      callback_url = "&redirect_uri=#{AppConfig['integrations_url'][Rails.env]}/auth/#{app_name}/callback"
    end

    def scopes(provider_key_name, oauth_keys)
      scopes = "&scope=" << oauth_keys["#{provider_key_name}"]['options']['scope'].tr(" ","+")
    end

    def options_name(app_name)
      options_name = "&name=#{app_name}"
    end

    def make_user_active user
      user.update_attributes(:active => 1)

    end

    def google_app_name provider_key_name, oauth_keys
      app_name = oauth_keys["#{provider_key_name}"]['options']['name']
    end

    def verify_gadget_user user
      if user.blank?
        @gadget_error = true
        @notice = t(:'flash.gmail_gadgets.user_missing')
      end
    end

    def verify_gadget_viewer_id google_viewer_id_hash, user
      google_viewer_id = google_viewer_id_from_hash(google_viewer_id_hash)
      if google_viewer_id.present?
        set_agent_google_viewer_id(google_viewer_id, user)
      else
        @gadget_error = true
        @notice = t(:'flash.gmail_gadgets.kvp_missing')
      end
    end

    def set_agent_google_viewer_id google_viewer_id, user
      agent = user.agent
      if agent.present?
        agent.google_viewer_id = google_viewer_id
        agent.save!
      else
        @gadget_error = true
        @notice = t(:'flash.gmail_gadgets.agent_missing')
      end
    end

    def google_viewer_id_from_hash hash
      key_options = {:account_id => login_account.id, :token => hash}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(AUTH_REDIRECT_GOOGLE_OPENID, key_options))
      kv_store.group = :integration
      google_viewer_id = kv_store.get_key
    end
end