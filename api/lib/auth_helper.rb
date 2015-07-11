class AuthHelper
  class << self
    def get_email_user(username, pwd)
      user = User.find_by_user_emails(username) # existing method used by authlogic to find user
      if user && !user.deleted
        valid_password = user.valid_password?(pwd) # valid_password - AuthLogic method
        if valid_password
          # reset failed_login_count only when it has changed. This is to prevent unnecessary save on user.
          AuthHelper.update_failed_login_count(user, true) if user.failed_login_count != 0
          user
        else
          AuthHelper.update_failed_login_count(user)
          nil
        end
      end
    end

    # This increases for each consecutive failed login.
    # See Authlogic::Session::BruteForceProtection and the consecutive_failed_logins_limit config option for more details.
    def update_failed_login_count(user, reset = false)
      if reset
        user.failed_login_count = 0
      else
        user.failed_login_count ||= 0
        user.failed_login_count += 1
      end
      user.save
    end

    # Authlogic does not change the column values if logged in by a session, cookie, or basic http auth
    def get_token_user(username)
      user = User.find_by_single_access_token(username)
      return user if user && !user.deleted && !user.blocked && user.active?
    end
  end
end
