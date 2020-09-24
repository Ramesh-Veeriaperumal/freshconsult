module Admin
  module SecurityTestHelper
    VALID_SECURITY_SETTINGS = [
      {
        notification_emails: [
          'padhu@gmail.com'
        ]
      },
      { whitelisted_ip: { enabled: true, applies_only_to_agents: true, ip_ranges: [{ start_ip: '11.11.11.00', end_ip: '11.11.11.11' }] } },
      { contact_password_policy: { minimum_characters: 9 } },
      { agent_password_policy: { minimum_characters: 10, cannot_be_same_as_past_passwords: 4, atleast_an_alphabet_and_number: nil } },
      { allow_iframe_embedding: true }
    ].freeze
    INVALID_SECURITY_SETTINGS = [
      { notification_emails: 1 }, # 0
      { notification_emails: 'abc' },
      { notification_emails: nil },
      { whitelisted_ip: { enabled: 0 } }, # 3
      { whitelisted_ip: { applies_only_to_agents: 'yes' } },
      { whitelisted_ip: { ip_ranges: [{ start_ip: 1, end_ip: 2 }] } },
      { whitelisted_ip: { ip_ranges: [1, 2] } }, # 6
      { whitelisted_ip: { ip_ranges: [] } },
      { whitelisted_ip: {} },
      { contact_password_policy: { minimum_characters: 140 } }, # 9
      { contact_password_policy: { minimum_characters: nil } },
      { contact_password_policy: { cannot_be_same_as_past_passwords: 100 } },
      { contact_password_policy: { cannot_contain_user_name: false } }, # 12
      { contact_password_policy: { cannot_contain_user_name: nil } },
      { contact_password_policy: { password_expiry: nil } },
      { contact_password_policy: { password_expiry: 78 } }, # 15
      { contact_password_policy: {} },
      { agent_password_policy: {} },
      {
        contact_password_policy: {
          minimum_characters: 'one',
          cannot_be_same_as_past_passwords: 'open',
          have_mixed_case: 'one',
          have_special_character: 'two',
          atleast_an_alphabet_and_number: 'pair',
          password_expiry: true
        }
      }, # 18
      { allow_iframe_embedding: 1 },
      { allow_iframe_embedding: nil }
    ].freeze

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
      password_policy.policy_config_mapping
    end

    def security_index_api_response_pattern(public_api: false)
      {}.tap do |settings|
        settings[:sso] = sso_settings(public_api) if Account.current.freshdesk_sso_configurable?
        settings[:whitelisted_ip] = whitelisted_ip_settings if Account.current.whitelisted_ips_enabled?
        settings[:help_widget] = help_widget if Account.current.help_widget_enabled?
        settings[:notification_emails] = Account.current.notification_emails
        settings[:contact_password_policy] = contact_password_policy_hash if Account.current.custom_password_policy_enabled?
        settings[:agent_password_policy] = agent_password_policy_hash if show_agent_password_policy?
        settings[:allow_iframe_embedding] = Account.current.allow_iframe_embedding
      end
    end

    def whitelisted_ip_settings
      Account.current.whitelisted_ip.present? ? show_whitelisted_ip : Admin::SecurityConstants::WHITELISTED_IP_NOT_CONFIGURED
    end

    def show_whitelisted_ip
      {
        enabled: Account.current.whitelisted_ip.enabled,
        applies_only_to_agents: Account.current.whitelisted_ip.applies_only_to_agents,
        ip_ranges: Account.current.whitelisted_ip.ip_ranges
      }
    end

    def help_widget
      { key: Account.current.help_widget_secret }
    end

    PasswordPolicy::USER_TYPE.keys.each do |value|
      define_method "#{value}_password_policy_hash" do
        fetch_password_policy(value) if Account.current.safe_send("#{value}_password_policy").present?
      end
    end

    def fetch_password_policy(type)
      password_policy = Account.current.safe_send("#{type}_password_policy")
      password_policy.policy_config_mapping
    end

    def show_agent_password_policy?
      !Account.current.freshid_integration_enabled? && Account.current.custom_password_policy_enabled? && Account.current.agent_password_policy.present?
    end

    def sso_settings(public_api)
      public_api ? public_sso : private_sso
    end

    def public_sso
      {}.tap do |sso|
        sso[:enabled] = Account.current.sso_enabled
        if Account.current.sso_enabled
          type = sso[:type] = Account.current.current_sso_type
          sso[type.to_sym] = safe_send("#{type}_sso") if type.present? && Account.current.freshdesk_sso_enabled?
        end
      end
    end

    def private_sso
      {}.tap do |sso|
        sso[:enabled] = Account.current.sso_enabled
        type = sso[:type] = Account.current.current_sso_type
        sso[type.to_sym] = safe_send("#{type}_sso") if type.present? && Account.current.freshdesk_sso_enabled?
        sso[:simple] ||= { shared_secret: Account.current.shared_secret }
      end
    end

    def simple_sso(sso_options = Account.current.sso_options)
      {
        'login_url' => sso_options[:login_url],
        'logout_url' => sso_options[:logout_url],
        'shared_secret' => Account.current.shared_secret
      }
    end

    def saml_sso(sso_options = Account.current.sso_options)
      {
        'login_url' => sso_options[:saml_login_url],
        'logout_url' => sso_options[:saml_logout_url],
        'saml_cert_fingerprint' => sso_options[:saml_cert_fingerprint]
      }
    end
  end
end
