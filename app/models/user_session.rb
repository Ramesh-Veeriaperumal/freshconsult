class UserSession < Authlogic::Session::Base
  
  include AgentLoggerHelper

  @@sign_cookie = true
  #Custom login method in user.rb
	find_by_login_method :find_by_user_emails
  params_key :k
  single_access_allowed_request_types :any
  before_save :set_last_active_time
  after_save :set_user_time_zone, :set_node_session
  before_destroy :delete_node_session
  after_validation :set_missing_node_session
  validate :account_lockdown_warning
  generalize_credentials_error_messages true
  consecutive_failed_logins_limit 10

  ACCOUNT_LOCKDOWN_WARNING_LIMIT = 7

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
  
  def account_lockdown_warning
    if errors.any?
      custom_error = false
      errors.each do |attrribute, error|
        if error.include?("Password combination is not valid") or error.include?("Consecutive failed logins limit exceeded")
          errors.clear
          custom_error = true
          break
        end
      end
      if custom_error and exceeded_failed_logins_warning_limit?
        if attempted_record.failed_login_count >= consecutive_failed_logins_limit
          #Modify the authlogic account locked message
          errors.add(:base, I18n.t("flash.login.account_locked_warning"))
        else
          #Show countdown to account lockout
          attempt = consecutive_failed_logins_limit-attempted_record.failed_login_count
          errors.add(:base, I18n.t("flash.login.failed_login_warning_line_1", :count => attempt))
          errors.add(:base, I18n.t("flash.login.failed_login_warning_line_2"))
          errors.add(:base, I18n.t("flash.login.failed_login_warning_line_3"))
        end
      else
        #The usual password does not match error
        errors.add(:base, I18n.t("flash.login.credentials_incorrect"))
      end
    end
  end

  def set_last_active_time
    self.record.agent.update_last_active(:force) if self.record.agent? and !self.record.agent.nil?   
  end

  attr_accessor :email, :password
  password_field(:password)

  private
    def exceeded_failed_logins_warning_limit?
      !attempted_record.nil? && attempted_record.respond_to?(:failed_login_count) && consecutive_failed_logins_limit > 0 &&
      attempted_record.failed_login_count.to_i >= ACCOUNT_LOCKDOWN_WARNING_LIMIT
    end

end
