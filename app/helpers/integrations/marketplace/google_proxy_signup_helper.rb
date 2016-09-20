module Integrations::Marketplace::GoogleProxySignupHelper
  include Integrations::GoogleAppsHelper

  def google_sso proxy_auth_user
    create_google_remote_account(@account, @remote_id, proxy_auth_user)
    user = @account.users.find_by_email(@email) || new_user(@account, @name, @email)
    create_auth(user, @uid, @account.id)
    domain_arg = @account.host
    random_key = SecureRandom.hex
    set_redis_sso(random_key, @uid)
    url = redirect_url(@account, domain_arg, random_key)
    redirect_to "#{url}"
  end

  private

    def new_user(account, name, email)
      user = account.users.new
      user.active = true
      user.signup!(:user => {
        :name => name,
        :email => email,
        :language => account.language
      })
      user
    end

    def set_redis_sso(key, uid)
      redis_oauth_key = GOOGLE_OAUTH_SSO % {:random_key => key}
      set_others_redis_key(redis_oauth_key, uid, 300)
    end

    def create_google_remote_account account, remote_id, user
      Integrations::GoogleRemoteAccount.create!(:account_id => account.id,
        :remote_id => remote_id, :configs => { :user_id => user.id, :user_email => user.email })
    end

end