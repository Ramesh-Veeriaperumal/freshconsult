module FDPasswordPolicy::Constants

  PASSWORD_POLICIES = YAML.load_file(File.join(Rails.root, 'config', 'password_policies.yml'))[:policies]
  POLICIES_BY_NAME = PASSWORD_POLICIES.keys

  DEFAULT_PASSWORD_POLICIES = [:minimum_characters, :cannot_contain_user_name, :password_expiry]

  CONFIG_REQUIRED_POLICIES = [:minimum_characters, :cannot_be_same_as_past_passwords, :password_expiry, :session_expiry]

  NEVER = (365*100).to_s #expires in 100 years if 'Never' is chosen.

  DEFAULT_CONFIGS = {
    "minimum_characters" => "8",
    "session_expiry" => "90",
    "password_expiry" => NEVER,
    "cannot_be_same_as_past_passwords" => "3"
  }

  ALPHANUMERIC_REGEX = /(?=.*\d)(?=.*([a-z]|[A-Z]))/
  MIXED_CASE_REGEX = /(?=.*[a-z])(?=.*[A-Z])/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/

  GRACE_PERIOD = 8.hours

  POLICY_TYPE = {
    advanced: 2,
    default: 1
  }.freeze

  POLICY_VALUE_RANGE = {
    minimum_characters: {
      min: 8,
      max: 99
    },
    cannot_be_same_as_past_passwords: {
      min: 1,
      max: 5
    }
  }.freeze
  POLICY_USER_TYPES = [:contact, :agent].freeze
  PASSWORD_EXPIRY_VALUES = ((1..6).collect { |x| (x * 30) } << NEVER.to_i).freeze
end
