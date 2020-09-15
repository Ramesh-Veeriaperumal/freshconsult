# frozen_string_literal: true

module Admin
  class SecurityDecorator < ApiDecorator
    include Redis::OthersRedis
    include Admin::SecurityConstants
    extend ActsAsApi::Base
    acts_as_api

    delegate :whitelisted_ip, :help_widget_secret, :notification_emails, :contact_password_policy, :agent_password_policy, to: :record

    def to_hash
      as_api_response(:security_api)
    end

    api_accessible :security_api do |u|
      u.add :whitelisted_ip_settings, if: proc { Account.current.whitelisted_ips_enabled? }, as: :whitelisted_ip
      u.add :help_widget, if: proc { Account.current.help_widget_enabled? }
      u.add :notification_emails
      u.add :contact_password_policy_hash, if: proc { Account.current.custom_password_policy_enabled? }, as: :contact_password_policy
      u.add :agent_password_policy_hash, if: proc { |obj| obj.show_agent_password_policy? }, as: :agent_password_policy
    end

    def whitelisted_ip_settings
      whitelisted_ip.present? ? show_whitelisted_ip : WHITELISTED_IP_NOT_CONFIGURED
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
