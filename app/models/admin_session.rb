class AdminSession < Authlogic::Session::Base
	authenticate_with AdminUser
	logout_on_timeout true
	attr_accessor :email, :password, :match
	generalize_credentials_error_messages true
end
