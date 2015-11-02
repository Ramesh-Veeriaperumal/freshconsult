class UserSession < Authlogic::Session::Base
  
  include AgentLoggerHelper

  @@sign_cookie = true
  #Custom login method in user.rb
	find_by_login_method :find_by_user_emails
  params_key :k
  single_access_allowed_request_types :any
  after_save :set_user_time_zone, :set_node_session
  before_destroy :delete_node_session
  after_validation :set_missing_node_session
  generalize_credentials_error_messages true
  consecutive_failed_logins_limit 10

  SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"

  def self.sign_cookie
    @@sign_cookie
  end
  
  def set_user_time_zone
    Time.zone = self.attempted_record.time_zone
  end

  def set_node_session
    generated_hash = Digest::SHA512.hexdigest("#{SECRET_KEY}::#{self.attempted_record.id}")
    controller.cookies['helpdesk_node_session'] = generated_hash
  end

  def delete_node_session
    controller.cookies.delete 'helpdesk_node_session'
  end
  
  def set_missing_node_session
    if controller.cookies['helpdesk_node_session'].blank?
      generated_hash = Digest::SHA512.hexdigest("#{SECRET_KEY}::#{self.attempted_record.id}")
      controller.cookies['helpdesk_node_session'] = generated_hash
    end
  end
  
  attr_accessor :email, :password
  password_field(:password)

end
