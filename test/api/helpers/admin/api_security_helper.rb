# frozen_string_literal: true

module Admin
  module ApiSecurityHelper
    def whitelisted_ip
      {
        'enabled' => true,
        'applies_only_to_agents' => true,
        'ip_ranges' => [{ 'start_ip' => '127.0.0.1', 'end_ip' => '127.0.0.10' }]
      }
    end

    def whitelisted_ip_not_configured
      {
        'enabled' => false
      }
    end

    def notification_emails
      ['test@test.com', 'test2@test.com']
    end

    def agent_password_policy
      {
        'user_type' => 2,
        'policies' => ['minimum_characters', 'cannot_contain_user_name', 'password_expiry'],
        'configs' => {
          'minimum_characters' => '8',
          'session_expiry' => '90',
          'password_expiry' => '36500',
          'cannot_be_same_as_past_passwords' => '3'
        }
      }
    end

    def password_policy(type = 'contact')
      password_policy = Account.current.safe_send("#{type}_password_policy")
      password_policy.policy_config_mapping.merge!(type: password_policy.password_policy_type)
    end

    def security_index_api_response_pattern
      {
        'whitelisted_ips' => {
          'enabled' => Account.current.whitelisted_ip.enabled,
          'applies_only_to_agents' => Account.current.whitelisted_ip.applies_only_to_agents,
          'ip_ranges' => Account.current.whitelisted_ip.ip_ranges
        },
        'help_widget' => {
          'key' => Account.current.help_widget_secret
        },
        'notification_emails' => Account.current.notification_emails,
        'contact_password_policy' => password_policy,
        'agent_password_policy' => password_policy('agent')
      }
    end
  end
end
