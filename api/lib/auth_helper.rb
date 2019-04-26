class AuthHelper
  class << self
    def get_email_user(username, pwd, ip)
      user = User.find_by_user_emails(username) # existing method used by authlogic to find user
      account = Account.current
      ApiAuthLogger.log "FRESHID API version=V2, auth_type=UN_PASS, a=#{account.id}"
      if user && !user.deleted
        Sharding.run_on_master do
          valid_pwd = account.freshid_integration_enabled? ? user.valid_freshid_password?(pwd) : user.valid_password?(pwd)
          user.update_failed_login_count(valid_pwd, username, ip)
        end
      end
    end

    # Authlogic does not change the column values if logged in by a session, cookie, or basic http auth
    def get_token_user(username)
      user = User.where(single_access_token: username).first
      ApiAuthLogger.log "FRESHID API version=V2, auth_type=API_KEY, a=#{Account.current.id}"
      return user if user && !user.deleted && !user.blocked && user.active?
    end
  end
end
