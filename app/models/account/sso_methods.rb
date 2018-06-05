class Account < ActiveRecord::Base

  def allow_sso_login?
    sso_enabled? || launched?(:whitelist_sso_login)
  end

  def set_sso_options_hash
    HashWithIndifferentAccess.new({:login_url => "",:logout_url => "", :sso_type => ""})
  end

  def agent_oauth2_sso_enabled?
    self.sso_options.present? && self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oauth2] && self.sso_options[:agent_oauth2] == true
  end

  def oauth2_sso_enabled?
    agent_oauth2_sso_enabled?
  end

  def enable_agent_oauth2_sso!(logout_redirect_url)
    puts "Freshid not enabled" and return unless self.freshid_enabled?
    add_feature(:oauth2)
    self.sso_options.merge!({ sso_type: SsoUtil::SSO_TYPES[:oauth2], agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: logout_redirect_url }})
    self.sso_enabled = true
    self.save
  end

  def disable_agent_oauth2_sso!
    revoke_feature(:oauth2)
    self.sso_options = { }
    self.sso_enabled = false
    self.save
  end

  def agent_oauth2_logout_redirect_url
    self.sso_options[:agent_oauth2_config][:logout_redirect_url] if self.agent_oauth2_sso_enabled? && self.sso_options[:agent_oauth2_config].present?
  end

  def is_saml_sso?
    self.sso_options.key? :sso_type and self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:saml]
  end

  def sso_login_url
    if self.is_saml_sso?
      self.sso_options[:saml_login_url]
    else
      self.sso_options[:login_url]
    end
  end

  #Simplified login and logout url helper methods for saml and simple SSO.
  def sso_logout_url
    if self.is_saml_sso?
      self.sso_options[:saml_logout_url]
    else
      self.sso_options[:logout_url]
    end
  end

  def reset_sso_options
    self.sso_options = set_sso_options_hash
  end

end