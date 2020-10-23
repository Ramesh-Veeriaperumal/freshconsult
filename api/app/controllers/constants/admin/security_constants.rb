# frozen_string_literal: true

module Admin::SecurityConstants
  include FDPasswordPolicy::Constants
  WHITELISTED_IP_LIMIT = 500
  SSO_TYPES = ['simple', 'saml'].freeze
  VALIDATION_CLASS = 'Admin::SecurityValidation'
  DELEGATOR_CLASS = 'Admin::SecurityDelegator'
  UPDATE_SECURITY_FIELDS = [
    'whitelisted_ip', 'notification_emails', 'contact_password_policy', 'agent_password_policy',
    'allow_iframe_embedding', 'sso', 'secure_attachments_enabled', 'secure_fields'
  ].freeze
  WHITELISTED_IP_NOT_CONFIGURED = {
    enabled: false
  }.freeze
  SSO_COEXIST_PERMITTED_PARAMS = [:enabled].freeze
  ALLOWED_SECURITY_FIELDS = [
    :notification_emails,
    {
      whitelisted_ip: [
        :enabled,
        :applies_only_to_agents,
        ip_ranges: [:start_ip, :end_ip].freeze
      ].freeze
    },
    {
      agent_password_policy: [
        :minimum_characters,
        :cannot_be_same_as_past_passwords,
        :have_mixed_case,
        :cannot_contain_user_name,
        :have_special_character,
        :atleast_an_alphabet_and_number,
        :password_expiry
      ].freeze
    },
    {
      contact_password_policy: [
        :minimum_characters,
        :cannot_be_same_as_past_passwords,
        :have_mixed_case,
        :cannot_contain_user_name,
        :have_special_character,
        :atleast_an_alphabet_and_number,
        :password_expiry
      ].freeze
    },
    :allow_iframe_embedding,
    {
      sso: [
        :enabled,
        :type,
        simple: [:login_url, :logout_url].freeze,
        saml: [:login_url, :logout_url, :saml_cert_fingerprint].freeze
      ].freeze
    },
    :secure_attachments_enabled,
    :secure_fields
  ].freeze

  SECURITY_NEW_SETTINGS = [:secure_attachments_enabled].freeze
  SSO_TYPE_NAMING_MAPPINGS = {
    simple: {
      login_url: 'login_url',
      logout_url: 'logout_url'
    },
    saml: {
      saml_login_url: 'login_url',
      saml_logout_url: 'logout_url',
      saml_cert_fingerprint: 'saml_cert_fingerprint'
    }
  }.freeze

  ATTRIBUTE_FEATURE_MAPPING = {
    whitelisted_ip: {
      enabled: ['whitelisted_ips'].freeze
    },
    contact_password_policy: {
      enabled: ['custom_password_policy'].freeze
    },
    agent_password_policy: {
      enabled: ['custom_password_policy'].freeze,
      disabled: ['freshid', 'freshid_org_v2'].freeze
    },
    secure_fields: {
      enabled: ['secure_fields_toggle', 'ticket_field_revamp'].freeze
    }
  }.freeze

  SSO_ERROR_REASON_MAPPING = {
    freshid_v2: 'account is in freshid v2',
    freshid_migration_in_progress: 'freshid migration is inprogress',
    coexist_account: 'freshid is integrated and freshdesk sso is configured'
  }.freeze

  # ----------- Validation ------------- #

  SIMPLE_SSO_HASH = {
    login_url: {
      data_type: { rules: String, allow_nil: false }.freeze
    }.freeze,
    logout_url: {
      data_type: { rules: String, allow_nil: true }.freeze
    }.freeze
  }.freeze

  SAML_SSO_HASH = {
    login_url: {
      data_type: { rules: String, allow_nil: false }.freeze
    }.freeze,
    logout_url: {
      data_type: { rules: String, allow_nil: true }.freeze
    }.freeze,
    saml_cert_fingerprint: {
      data_type: { rules: String, allow_nil: false }.freeze
    }.freeze
  }.freeze

  SSO_HASH = {
    enabled: { data_type: { rules: 'Boolean' } }.freeze,
    type: {
      data_type: { rules: String, allow_nil: true }.freeze,
      custom_inclusion: { in: SSO_TYPES }.freeze
    }.freeze,
    simple: {
      data_type: { rules: Hash }.freeze,
      hash: SIMPLE_SSO_HASH
    }.freeze,
    saml: {
      data_type: { rules: Hash }.freeze,
      hash: SAML_SSO_HASH
    }.freeze
  }.freeze

  POLICIES_CONFIGS_HASH = {
    minimum_characters: {
      data_type: { rules: Integer, allow_nil: false }.freeze,
      custom_numericality: {
        less_than: POLICY_VALUE_RANGE[:minimum_characters][:max] + 1,
        greater_than: POLICY_VALUE_RANGE[:minimum_characters][:min] - 1,
        message: 'should be within the range [8, 99]',
        allow_nil: true
      }.freeze
    }.freeze,
    cannot_be_same_as_past_passwords: {
      data_type: { rules: Integer, allow_nil: true }.freeze,
      custom_numericality: {
        less_than: POLICY_VALUE_RANGE[:cannot_be_same_as_past_passwords][:max] + 1,
        greater_than: POLICY_VALUE_RANGE[:cannot_be_same_as_past_passwords][:min] - 1,
        message: 'should be within the range [1, 5]',
        allow_nil: true
      }.freeze
    }.freeze,
    have_mixed_case: { data_type: { rules: 'Boolean', allow_nil: true } }.freeze,
    cannot_contain_user_name: {
      data_type: { rules: 'Boolean', allow_nil: false }.freeze,
      custom_inclusion: {
        in: [true]
      }.freeze
    }.freeze,
    have_special_character: { data_type: { rules: 'Boolean', allow_nil: true } }.freeze,
    atleast_an_alphabet_and_number: { data_type: { rules: 'Boolean', allow_nil: true } }.freeze,
    password_expiry: {
      data_type: { rules: Integer, allow_nil: false }.freeze,
      custom_inclusion: {
        in: PASSWORD_EXPIRY_VALUES
      }
    }.freeze
  }.freeze

  IP_RANGES_HASH = {
    start_ip: { data_type: { rules: String } }.freeze,
    end_ip: { data_type: { rules: String } }.freeze
  }.freeze

  WHITELISTED_IP_HASH = {
    enabled: { data_type: { rules: 'Boolean' } }.freeze,
    applies_only_to_agents: { data_type: { rules: 'Boolean' } }.freeze
  }.freeze

  SETTINGS_TO_IGNORE = ['secure_fields'].freeze
end
