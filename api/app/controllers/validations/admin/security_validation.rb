# frozen_string_literal: true

module Admin
  class SecurityValidation < ApiValidation
    include Admin::SecurityConstants

    attr_accessor :notification_emails, :sso, :whitelisted_ip, :contact_password_policy, :agent_password_policy,
                  :ip_ranges, :ssl
    validates :notification_emails, data_type: { rules: Array, not_empty: true }, array: {
      data_type: { rules: String },
      custom_format: {
        with: ApiConstants::EMAIL_REGEX,
        accepted: 'valid email'
      }
    }
    validates :whitelisted_ip, data_type: { rules: Hash, not_empty: true }, hash: WHITELISTED_IP_HASH

    validates :contact_password_policy, data_type: { rules: Hash, not_empty: true }, hash: POLICIES_CONFIGS_HASH

    validates :agent_password_policy, data_type: { rules: Hash, not_empty: true }, hash: POLICIES_CONFIGS_HASH

    validates :ip_ranges, data_type: { rules: Array, not_empty: true }, array: {
      data_type: { rules: Hash }, hash: IP_RANGES_HASH
    }, custom_length: {
      maximum: WHITELISTED_IP_LIMIT,
      message: :max_limit,
      message_options: {
        name: 'whitelisted_ip.ip_ranges',
        max_value: WHITELISTED_IP_LIMIT
      }
    }
  end
end
