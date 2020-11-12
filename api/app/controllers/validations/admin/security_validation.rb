# frozen_string_literal: true

module Admin
  class SecurityValidation < ApiValidation
    include Admin::SecurityConstants

    attr_accessor :notification_emails, :sso, :whitelisted_ip, :contact_password_policy, :agent_password_policy,
                  :ip_ranges, :allow_iframe_embedding, :secure_attachments_enabled, :secure_fields, :redaction
    validates :notification_emails, data_type: { rules: Array, not_empty: true }, array: {
      data_type: { rules: String },
      custom_format: {
        with: ApiConstants::EMAIL_REGEX,
        accepted: 'valid email'
      }
    }

    validates :allow_iframe_embedding, data_type: { rules: 'Boolean' }

    validates :secure_attachments_enabled, data_type: { rules: 'Boolean' }

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

    validates :redaction, data_type: { rules: Hash, not_empty: true }, hash: REDACTION_HASH

    validates :sso, data_type: { rules: Hash }, hash: SSO_HASH

    validate :check_sso_setting_keys, if: -> { sso.present? && errors[:sso].blank? }

    validates :secure_fields, data_type: { rules: 'Boolean' }

    def check_sso_setting_keys
      errors[:sso] << :more_than_one_sso_settings_available if (SSO_TYPES.map(&:to_sym) - sso.keys).empty?

      type = sso[:type].try(:to_sym)
      if sso.key?(:type) && sso[type].blank?
        errors[:sso] << :level_missing_field
        @error_options[:sso] = {
          field: type
        }
      end
      if sso_configuration_error.present?
        errors[:sso] << :action_restricted
        @error_options[:sso] = { action: 'sso configuration', reason: sso_configuration_error, attribute: :sso }
      end
    end

    def sso_configuration_error
      @sso_configuration_error ||= begin
        if !Account.current.freshdesk_sso_configurable?
          SSO_ERROR_REASON_MAPPING[:freshid_v2]
        elsif Account.current.freshid_migration_in_progress?
          SSO_ERROR_REASON_MAPPING[:freshid_migration_in_progress]
        elsif Account.current.coexist_account? && unpermitted_coexist_sso_param?
          SSO_ERROR_REASON_MAPPING[:coexist_account]
        end
      end
    end

    def unpermitted_coexist_sso_param?
      (sso.keys.map(&:to_sym) - SSO_COEXIST_PERMITTED_PARAMS).present?
    end
  end
end
