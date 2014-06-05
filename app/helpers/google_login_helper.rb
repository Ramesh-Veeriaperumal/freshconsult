module GoogleLoginHelper

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
    @request_domain ||= auth_hash['extra']['raw_info']['hd'] || params[:state]
  end

  def construct_google_auth_url(portal_url)
    oauth_keys = Integrations::OauthHelper::get_oauth_keys
    auth_url = "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=" << consumer_token(oauth_keys) << callback_url << scopes << options_name
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

  def consumer_token(oauth_keys)
    consumer_token = oauth_keys['google_oauth2']['consumer_token']
  end

  def callback_url
    callback_url = "&redirect_uri=#{AppConfig['integrations_url'][Rails.env]}/auth/google_login/callback"
  end

  def scopes
    scopes = "&scope=https://www.googleapis.com/auth/userinfo.email+https://www.googleapis.com/auth/calendar"
  end

  def options_name
    options_name = "&name=google_login"
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
      created_user = create_user(login_account, name, email)
      create_auth(created_user, uid, login_account.id)
    elsif !domain_user.active?
      make_user_active domain_user
    end
  end

  def make_user_active user
    user.update_attributes(:active => 1)
  end

end