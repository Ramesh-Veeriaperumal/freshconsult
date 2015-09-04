class AuthHelper
  class << self
    def get_email_user(username, pwd, ip)
      user = User.find_by_user_emails(username) # existing method used by authlogic to find user
      if user && !user.deleted
        valid_pwd = user.valid_password?(pwd) # valid_password - AuthLogic method
        user.update_failed_login_count(valid_pwd, username, ip)
      end
    end

    # Authlogic does not change the column values if logged in by a session, cookie, or basic http auth
    def get_token_user(username)
      user = User.where(single_access_token: username).first
      return user if user && !user.deleted && !user.blocked && user.active?
    end
  end
end
