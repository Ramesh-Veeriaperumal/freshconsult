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
      { agent_password_policy: { minimum_characters: 10, cannot_be_same_as_past_passwords: 4, atleast_an_alphabet_and_number: nil } }
    ].freeze
    INVALID_SECURITY_SETTINGS = [
      { notification_emails: 1 },
      { notification_emails: 'abc' },
      { notification_emails: nil },
      { whitelisted_ip: { enabled: 0 } },
      { whitelisted_ip: { applies_only_to_agents: 'yes' } },
      { whitelisted_ip: { ip_ranges: [{ start_ip: 1, end_ip: 2 }] } },
      { whitelisted_ip: { ip_ranges: [1, 2] } },
      { whitelisted_ip: { ip_ranges: [] } },
      { whitelisted_ip: {} },
      { contact_password_policy: { minimum_characters: 140 } },
      { contact_password_policy: { minimum_characters: nil } },
      { contact_password_policy: { cannot_be_same_as_past_passwords: 100 } },
      { contact_password_policy: { cannot_contain_user_name: false } },
      { contact_password_policy: { cannot_contain_user_name: nil } },
      { contact_password_policy: { password_expiry: nil } },
      { contact_password_policy: { password_expiry: 78 } },
      { contact_password_policy: {} },
      { agent_password_policy: {} },
      { contact_password_policy: { minimum_characters: 'one',
        cannot_be_same_as_past_passwords: 'open',
        have_mixed_case: 'one',
        have_special_character: 'two',
        atleast_an_alphabet_and_number: 'pair',
        password_expiry: true } }
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

    def security_index_api_response_pattern
      {
        'whitelisted_ip' => {
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
