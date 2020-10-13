# frozen_string_literal: true

module Admin
  class SecurityDecorator < ApiDecorator
    include Redis::OthersRedis
    include Admin::SecurityConstants
    extend ActsAsApi::Base
    acts_as_api

    delegate :whitelisted_ip, :help_widget_secret, :notification_emails, :contact_password_policy, :agent_password_policy, :sso_options, :shared_secret, :sso_enabled, :current_sso_type, :freshdesk_sso_enabled?, :allow_iframe_embedding, to: :record

    def to_hash
      if private_api?
        as_api_response(:private_api)
      else
        as_api_response(:public_api)
      end
    end

    api_accessible :security_api do |u|
      u.add :whitelisted_ip_settings, if: proc { Account.current.whitelisted_ips_enabled? }, as: :whitelisted_ip
      u.add :help_widget, if: proc { Account.current.help_widget_enabled? }
      u.add :notification_emails
      u.add :contact_password_policy_hash, if: proc { Account.current.custom_password_policy_enabled? }, as: :contact_password_policy
      u.add :agent_password_policy_hash, if: proc { |obj| obj.show_agent_password_policy? }, as: :agent_password_policy
      u.add :allow_iframe_embedding
      u.add :secure_attachments_enabled, if: proc { Account.current.security_new_settings_enabled? && Account.current.dependent_feature_enabled?(:secure_attachments) }
    end

    api_accessible :private_api, extend: :security_api do |u|
      u.add :private_sso, if: proc { Account.current.freshdesk_sso_configurable? }, as: :sso
    end

    api_accessible :public_api, extend: :security_api do |u|
      u.add :public_sso, if: proc { Account.current.freshdesk_sso_configurable? }, as: :sso
    end

    def private_sso
      {}.tap do |sso|
        sso[:enabled] = sso_enabled || false
        sso[:type] = current_sso_type
        sso[current_sso_type.to_sym] = safe_send("#{current_sso_type}_sso_settings") if freshdesk_sso_enabled?
        sso[:simple] ||= { shared_secret: shared_secret }
      end
    end

    def public_sso
      {}.tap do |sso|
        sso[:enabled] = sso_enabled || false
        if sso_enabled
          sso[:type] = current_sso_type
          sso[current_sso_type.to_sym] = safe_send("#{current_sso_type}_sso_settings") if freshdesk_sso_enabled?
        end
      end
    end

    def simple_sso_settings
      {
        login_url: sso_options[:login_url],
        logout_url: sso_options[:logout_url],
        shared_secret: shared_secret
      }
    end

    def saml_sso_settings
      {
        login_url: sso_options[:saml_login_url],
        logout_url: sso_options[:saml_logout_url],
        saml_cert_fingerprint: sso_options[:saml_cert_fingerprint]
      }
    end

    def whitelisted_ip_settings
      whitelisted_ip.present? ? show_whitelisted_ip : WHITELISTED_IP_NOT_CONFIGURED
    end

    def secure_attachments_enabled
      Account.current.secure_attachments_enabled?
    end

    def show_whitelisted_ip
      {
        enabled: whitelisted_ip.enabled,
        applies_only_to_agents: whitelisted_ip.applies_only_to_agents,
        ip_ranges: whitelisted_ip.ip_ranges
      }
    end

    def help_widget
      { key: help_widget_secret }
    end

    PasswordPolicy::USER_TYPE.keys.each do |value|
      define_method "#{value}_password_policy_hash" do
        fetch_password_policy(value) if safe_send("#{value}_password_policy").present?
      end
    end

    def fetch_password_policy(type)
      password_policy = safe_send("#{type}_password_policy")
      password_policy.policy_config_mapping
    end

    def show_agent_password_policy?
      !Account.current.freshid_integration_enabled? && Account.current.custom_password_policy_enabled? && Account.current.agent_password_policy.present?
    end
  end
end
