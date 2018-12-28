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

  def customer_oauth2_sso_enabled?
    self.sso_options.present? && self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oauth2] && self.sso_options[:customer_oauth2] == true
  end

  def oauth2_sso_enabled?
    agent_oauth2_sso_enabled? || customer_oauth2_sso_enabled?
  end

  def is_saml_sso?
    self.sso_options.key? :sso_type and self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:saml]
  end

  def enable_agent_oauth2_sso!(logout_redirect_url)
    puts "Freshid not enabled" or return unless self.freshid_enabled?
    add_feature(:oauth2)
    sso_config = { sso_type: SsoUtil::SSO_TYPES[:oauth2], agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = customer_oauth2_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_agent_oauth2_sso!
    return false unless self.agent_oauth2_sso_enabled?
    remove_agent_oauth2_sso_options
    disable_oauth2_sso unless customer_oauth2_sso_enabled?
    self.save
  end

  def enable_customer_oauth2_sso!(logout_redirect_url)
    puts "Freshid not enabled" or return unless self.freshid_enabled?
    add_feature(:oauth2)
    sso_config = { sso_type: SsoUtil::SSO_TYPES[:oauth2], customer_oauth2: true, customer_oauth2_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = agent_oauth2_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_customer_oauth2_sso!
    return false unless self.customer_oauth2_sso_enabled?
    remove_customer_oauth2_sso_options
    disable_oauth2_sso unless agent_oauth2_sso_enabled?
    self.save
  end

  def disable_oauth2_sso
    reset_feature(:oauth2)
    self.sso_options.delete(:sso_type) if self.sso_options.present?
    self.sso_enabled = false
  end

  def remove_oauth2_sso_options
    revoke_feature(:oauth2)
    remove_agent_oauth2_sso_options
    remove_customer_oauth2_sso_options
  end

  def remove_agent_oauth2_sso_options
    if self.sso_options.present?
      self.sso_options.delete(:agent_oauth2)
      self.sso_options.delete(:agent_oauth2_config)
    end
  end

  def remove_customer_oauth2_sso_options
    if self.sso_options.present?
      self.sso_options.delete(:customer_oauth2)
      self.sso_options.delete(:customer_oauth2_config)
    end
  end

  def agent_oauth2_logout_redirect_url
    self.sso_options[:agent_oauth2_config][:logout_redirect_url] if self.agent_oauth2_sso_enabled? && self.sso_options[:agent_oauth2_config].present?
  end

  def customer_oauth2_logout_redirect_url
    self.sso_options[:customer_oauth2_config][:logout_redirect_url] if self.customer_oauth2_sso_enabled? && self.sso_options[:customer_oauth2_config].present?
  end

  # ***************************************** FOR FRESHID SAML

  def freshid_sso_enabled?
    return oauth2_sso_enabled? || freshid_saml_sso_enabled?
  end

  def freshid_saml_sso_enabled?
    agent_freshid_saml_sso_enabled? || customer_freshid_saml_sso_enabled?
  end

  def agent_freshid_saml_sso_enabled?
    self.sso_options.present? && self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:freshid_saml] && self.sso_options[:agent_freshid_saml] == true
  end

  def customer_freshid_saml_sso_enabled?
    self.sso_options.present? && self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:freshid_saml] && self.sso_options[:customer_freshid_saml] == true
  end

  def enable_agent_freshid_saml_sso!(logout_redirect_url)
    puts "Freshid not enabled" or return unless self.freshid_enabled?
    add_feature(:freshid_saml)
    sso_config = { sso_type: SsoUtil::SSO_TYPES[:freshid_saml], agent_freshid_saml: true, agent_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = customer_freshid_saml_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_agent_freshid_saml_sso!
    return false unless self.agent_freshid_saml_sso_enabled?
    remove_agent_freshid_saml_sso_options
    disable_freshid_saml_sso unless customer_freshid_saml_sso_enabled?
    self.save
  end

  def enable_customer_freshid_saml_sso!(logout_redirect_url)
    puts "Freshid not enabled" or return unless self.freshid_enabled?
    add_feature(:freshid_saml)
    sso_config = { sso_type: SsoUtil::SSO_TYPES[:freshid_saml], customer_freshid_saml: true, customer_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = agent_freshid_saml_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_customer_freshid_saml_sso!
    return false unless self.customer_freshid_saml_sso_enabled?
    remove_customer_freshid_saml_sso_options
    disable_freshid_saml_sso unless agent_freshid_saml_sso_enabled?
    self.save
  end

  def disable_freshid_saml_sso
    reset_feature(:freshid_saml)
    self.sso_options.delete(:sso_type) if self.sso_options.present?
    self.sso_enabled = false
  end

  def remove_freshid_saml_sso_options
    revoke_feature(:freshid_saml)
    remove_agent_freshid_saml_sso_options
    remove_customer_freshid_saml_sso_options
  end

  def remove_agent_freshid_saml_sso_options
    if self.sso_options.present?
      self.sso_options.delete(:agent_freshid_saml)
      self.sso_options.delete(:agent_freshid_saml_config)
    end
  end

  def remove_customer_freshid_saml_sso_options
    if self.sso_options.present?
      self.sso_options.delete(:customer_freshid_saml)
      self.sso_options.delete(:customer_freshid_saml_config)
    end
  end

  def agent_freshid_saml_logout_redirect_url
    self.sso_options[:agent_freshid_saml_config][:logout_redirect_url] if self.agent_freshid_saml_sso_enabled? && self.sso_options[:agent_freshid_saml_config].present?
  end

  def customer_freshid_saml_logout_redirect_url
    self.sso_options[:customer_freshid_saml_config][:logout_redirect_url] if self.customer_freshid_saml_sso_enabled? && self.sso_options[:customer_freshid_saml_config].present?
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