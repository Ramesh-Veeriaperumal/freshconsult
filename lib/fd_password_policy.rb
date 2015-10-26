require "fd_password_policy/acts_as_authentic/password_format"
require "fd_password_policy/acts_as_authentic/periodic_logged_in_status"
require "fd_password_policy/session/periodic_login_timeout"
require "fd_password_policy/regex"

#Password format, history and contains username
ActiveRecord::Base.send(:include, FDPasswordPolicy::ActsAsAuthentic::PasswordFormat)
#Periodic login
ActiveRecord::Base.send(:include, FDPasswordPolicy::ActsAsAuthentic::PeriodicLoggedInStatus)
Authlogic::Session::Base.send(:include, FDPasswordPolicy::Session::PeriodicLoginTimeout)
#Password expiry
ActiveRecord::Base.send(:include, FDPasswordPolicy::ActsAsAuthentic::PasswordExpiryStatus)
Authlogic::Session::Base.send(:include, FDPasswordPolicy::Session::PasswordExpiryTimeout)