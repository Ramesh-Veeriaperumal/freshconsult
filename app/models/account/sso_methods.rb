class Account < ActiveRecord::Base

  RAILS_LOGGER_PREFIX = 'FRESHID CUSTOM POLICY :: SSO METHODS :: '.freeze

  def allow_sso_login?
    (sso_enabled? && (is_saml_sso? || is_simple_sso?)) || launched?(:whitelist_sso_login)
  end

  def set_sso_options_hash
    HashWithIndifferentAccess.new({:login_url => "",:logout_url => "", :sso_type => ""})
  end

  def freshdesk_sso_enabled?
    sso_enabled && (is_simple_sso? || is_saml_sso?)
  end

  def oauth2_sso_enabled?
    sso_options.present? &&
        (sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oauth2] ||
            sso_options[:agent_oauth2] == true ||
            sso_options[:customer_oauth2] == true)
  end

  def agent_oauth2_sso_enabled?
    oauth2_sso_enabled? && sso_options[:agent_oauth2] == true
  end

  def customer_oauth2_sso_enabled?
    oauth2_sso_enabled? && sso_options[:customer_oauth2] == true
  end

  def is_saml_sso?
    sso_options.present? && sso_options[:sso_type] == SsoUtil::SSO_TYPES[:saml]
  end

  def is_simple_sso?
    sso_options.present? && sso_options[:sso_type] == SsoUtil::SSO_TYPES[:simple_sso]
  end

  # Freshid oauth2
  def enable_agent_oauth2_sso!(logout_redirect_url)
    puts 'Freshid not enabled' or return unless self.freshid_integration_enabled?
    if self.freshid_sso_sync_enabled?
      sso_config = { agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    else
      sso_config = { sso_type: SsoUtil::SSO_TYPES[:oauth2], agent_oauth2: true, agent_oauth2_config: { logout_redirect_url: logout_redirect_url } }
      self.sso_options = customer_oauth2_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    end
    self.sso_enabled = true
    self.save
  end

  def disable_agent_oauth2_sso!
    return false unless self.agent_oauth2_sso_enabled?
    remove_agent_oauth2_sso_options
    disable_oauth2_sso
    self.save
  end

  def enable_customer_oauth2_sso!(logout_redirect_url)
    puts 'Freshid not enabled' or return unless self.freshid_integration_enabled?
    if self.freshid_sso_sync_enabled?
      sso_config = { customer_oauth2: true, customer_oauth2_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    else
      sso_config = { sso_type: SsoUtil::SSO_TYPES[:oauth2], customer_oauth2: true, customer_oauth2_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = agent_oauth2_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    end
    self.sso_enabled = true
    self.save
  end

  def disable_customer_oauth2_sso!
    return false unless self.customer_oauth2_sso_enabled?
    remove_customer_oauth2_sso_options
    disable_oauth2_sso
    self.save
  end

  def disable_oauth2_sso
    self.sso_options.delete(:sso_type) if sso_options.present? && sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oauth2]
    self.sso_enabled = false unless sso_options.present?
  end

  def remove_oauth2_sso_options
    remove_agent_oauth2_sso_options
    remove_customer_oauth2_sso_options
  end

  def remove_agent_oauth2_sso_options
    if sso_options.present?
      self.sso_options.delete(:agent_oauth2)
      self.sso_options.delete(:agent_oauth2_config)
    end
  end

  def remove_customer_oauth2_sso_options
    if sso_options.present?
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

  ################################## Freshid oidc
  def oidc_sso_enabled?
    sso_options.present? && (sso_options[:agent_oidc] == true || sso_options[:customer_oidc] == true)
  end

  def agent_oidc_sso_enabled?
    sso_options.present? && sso_options[:agent_oidc] == true
  end

  def customer_oidc_sso_enabled?
    sso_options.present? && sso_options[:customer_oidc] == true
  end

  def enable_agent_oidc_sso!(logout_redirect_url)
    puts 'Freshid not enabled' or return unless self.freshid_integration_enabled?
    sso_config = { agent_oidc: true, agent_oidc_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_agent_oidc_sso!
    return false unless self.agent_oidc_sso_enabled?
    remove_agent_oidc_sso_options
    disable_oidc_sso
    self.save
  end

  def enable_customer_oidc_sso!(logout_redirect_url)
    puts 'Freshid not enabled' || return unless self.freshid_integration_enabled?
    sso_config = { customer_oidc: true, customer_oidc_config: { logout_redirect_url: logout_redirect_url }}
    self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_customer_oidc_sso!
    return false unless self.customer_oidc_sso_enabled?
    remove_customer_oidc_sso_options
    disable_oidc_sso
    self.save
  end

  def disable_oidc_sso
    self.sso_options.delete(:sso_type) if sso_options.present? && sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oidc]
    self.sso_enabled = false unless sso_options.present?
  end

  def remove_oidc_sso_options
    remove_agent_oidc_sso_options
    remove_customer_oidc_sso_options
  end

  def remove_agent_oidc_sso_options
    if sso_options.present?
      self.sso_options.delete(:agent_oidc)
      self.sso_options.delete(:agent_oidc_config)
    end
  end

  def remove_customer_oidc_sso_options
    if sso_options.present?
      self.sso_options.delete(:customer_oidc)
      self.sso_options.delete(:customer_oidc_config)
    end
  end

  def agent_oidc_logout_redirect_url
    self.sso_options[:agent_oidc_config][:logout_redirect_url] if self.agent_oidc_sso_enabled? && self.sso_options[:agent_oidc_config].present?
  end

  def customer_oidc_logout_redirect_url
    self.sso_options[:customer_oidc_config][:logout_redirect_url] if self.customer_oidc_sso_enabled? && self.sso_options[:customer_oidc_config].present?
  end
  
  # ***************************************** FOR FRESHID SAML

  def freshid_sso_enabled?
    sso_options.present? && sso_options.keys.any? {|key| SsoUtil::FRESHID_SSO.include?(key.to_s)}
  end

  def sso_configured?
    freshdesk_sso_enabled? || freshid_sso_enabled?
  end

  def freshid_saml_sso_enabled?
   sso_options.present? &&
    (sso_options[:sso_type] == SsoUtil::SSO_TYPES[:freshid_saml] ||
        sso_options[:agent_freshid_saml] == true ||
        sso_options[:customer_freshid_saml] == true)
  end

  def agent_freshid_saml_sso_enabled?
    freshid_saml_sso_enabled? && sso_options[:agent_freshid_saml] == true
  end

  def customer_freshid_saml_sso_enabled?
    freshid_saml_sso_enabled? && sso_options[:customer_freshid_saml] == true
  end

  def enable_agent_freshid_saml_sso!(logout_redirect_url)
    puts 'Freshid not enabled' || return unless self.freshid_integration_enabled?
    if self.freshid_sso_sync_enabled?
      sso_config = { agent_freshid_saml: true, agent_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    else
      sso_config = { sso_type: SsoUtil::SSO_TYPES[:freshid_saml], agent_freshid_saml: true, agent_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = customer_freshid_saml_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    end
    self.sso_enabled = true
    self.save
  end

  def disable_agent_freshid_saml_sso!
    return false unless self.agent_freshid_saml_sso_enabled?
    remove_agent_freshid_saml_sso_options
    disable_freshid_saml_sso
    self.save
  end

  def enable_customer_freshid_saml_sso!(logout_redirect_url)
    puts 'Freshid not enabled' || return unless self.freshid_integration_enabled?
    if self.freshid_sso_sync_enabled?
      sso_config = { customer_freshid_saml: true, customer_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    else
      sso_config = { sso_type: SsoUtil::SSO_TYPES[:freshid_saml], customer_freshid_saml: true, customer_freshid_saml_config: { logout_redirect_url: logout_redirect_url }}
      self.sso_options = agent_freshid_saml_sso_enabled? ? self.sso_options.merge(sso_config) : sso_config
    end
    self.sso_enabled = true
    self.save
  end

  def disable_customer_freshid_saml_sso!
    return false unless self.customer_freshid_saml_sso_enabled?
    remove_customer_freshid_saml_sso_options
    disable_freshid_saml_sso
    self.save
  end

  def disable_freshid_saml_sso
    self.sso_options.delete(:sso_type) if sso_options.present? && sso_options[:sso_type] == SsoUtil::SSO_TYPES[:freshid_saml]
    self.sso_enabled = false unless sso_options.present?
  end

  def remove_freshid_saml_sso_options
    remove_agent_freshid_saml_sso_options
    remove_customer_freshid_saml_sso_options
  end

  def remove_agent_freshid_saml_sso_options
    if sso_options.present?
      self.sso_options.delete(:agent_freshid_saml)
      self.sso_options.delete(:agent_freshid_saml_config)
    end
  end

  def remove_customer_freshid_saml_sso_options
    if sso_options.present?
      self.sso_options.delete(:customer_freshid_saml)
      self.sso_options.delete(:customer_freshid_saml_config)
    end
  end

  def agent_freshid_saml_logout_redirect_url
    sso_options[:agent_freshid_saml_config][:logout_redirect_url] if agent_freshid_saml_sso_enabled? && sso_options[:agent_freshid_saml_config].present?
  end

  def customer_freshid_saml_logout_redirect_url
    sso_options[:customer_freshid_saml_config][:logout_redirect_url] if customer_freshid_saml_sso_enabled? && sso_options[:customer_freshid_saml_config].present?
  end

  def sso_login_url
    if self.is_saml_sso?
      self.sso_options[:saml_login_url]
    else
      self.sso_options[:login_url]
    end
  end

  # toggle agent_custom_sso
  def enable_agent_custom_sso!(entrypoint_config)
    unless freshid_integration_enabled?
      Rails.logger.info "#{RAILS_LOGGER_PREFIX} Enable Agent Custom SSO :: Freshid integeration not enabled"
      return
    end
    sso_config = { agent_custom_sso: true, agent_custom_sso_config: entrypoint_config }
    self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_agent_custom_sso!
    return false unless self.agent_custom_sso_enabled?
    remove_agent_custom_sso_options
    disable_freshid_sso
    self.save
  end

  def agent_custom_sso_enabled?
    self.sso_options[:agent_custom_sso] == true
  end

  def remove_agent_custom_sso_options
    if sso_options.present?
      self.sso_options.delete(:agent_custom_sso)
      self.sso_options.delete(:agent_custom_sso_config)
    end
  end

  def disable_freshid_sso
    self.sso_enabled = false unless sso_options.present?
  end

  # @params entity => :agent or :contact
  def custom_policy_login_url(entity)
    account_additional_settings.additional_settings[:freshid_custom_policy_configs][entity][:entrypoint_url] if freshid_custom_policy_enabled?(entity)
  end

  def agent_custom_login_url
    return custom_policy_login_url(:agent) if freshid_custom_policy_enabled?(:agent)

    # Need to Remove below code after migration
    self.sso_options[:agent_custom_sso_config][:entrypoint_url] if self.agent_custom_sso_enabled?
  end

  def customer_custom_login_url
    return custom_policy_login_url(:contact) if freshid_custom_policy_enabled?(:contact)

    # Need to Remove below code after migration
    self.sso_options[:customer_custom_sso_config][:entrypoint_url] if self.contact_custom_sso_enabled?
  end

  # toggle contact_custom_sso
  def enable_contact_custom_sso!(entrypoint_config)
    unless freshid_org_v2_enabled?
      Rails.logger.info "#{RAILS_LOGGER_PREFIX} Enable Contact Custom SSO :: Freshid not enabled"
      return
    end
    sso_config = { customer_custom_sso: true, customer_custom_sso_config: entrypoint_config }
    self.sso_options = sso_configured? ? sso_options.merge(sso_config) : sso_config
    self.sso_enabled = true
    self.save
  end

  def disable_contact_custom_sso!
    return false unless self.contact_custom_sso_enabled?
    remove_contact_custom_sso_options
    disable_freshid_sso
    self.save
  end

  def contact_custom_sso_enabled?
    self.sso_options[:customer_custom_sso] == true
  end

  def remove_contact_custom_sso_options
    if sso_options.present?
      self.sso_options.delete(:customer_custom_sso)
      self.sso_options.delete(:customer_custom_sso_config)
    end
  end

  def freshid_custom_sso_exists?(entity)
    sso_config_key = entity == :contact ? 'customer_custom_sso' : 'agent_custom_sso'
    sso_options[sso_config_key.to_sym] && sso_options["#{sso_config_key}_config".to_sym]
  end

  def agent_default_sso_enabled?
    agent_freshid_saml_sso_enabled? ||
        agent_oauth2_sso_enabled? ||
        agent_oidc_sso_enabled?
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

  def remove_freshdesk_sso_options
    remove_saml_sso_options
    remove_simple_sso_options
    self.sso_options.delete(:sso_type)
  end

  def remove_saml_sso_options
    if sso_options.present?
      SsoUtil::FRESHDESK_SAML_SSO_CONFIG_KEYS.each do |key|
        self.sso_options.delete(key)
      end
    end
  end

  def remove_simple_sso_options
    if sso_options.present?
      SsoUtil::FRESHDESK_SIMPLE_SSO_CONFIG_KEYS.each do |key|
        self.sso_options.delete(key)
      end
    end
  end
end