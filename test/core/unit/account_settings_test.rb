require_relative '../test_helper'

class AccountSettingsTest < ActiveSupport::TestCase
  ALLOWED_KEYS = ['internal', 'default', 'feature_dependency', 'settings_dependency'].freeze
  OPTIONAL_KEYS = ['settings_dependency'].freeze

  def test_validate_account_settings_for_no_additional_keys
    settings_hash = AccountSettings::SettingsConfig
    settings_hash.each do |key, config|
      assert (ALLOWED_KEYS - config.keys).empty?, "Extra keys in the settings config for #{key}"
    end
  end

  def test_validate_account_settings_for_missed_keys
    settings_hash = AccountSettings::SettingsConfig
    mandatory_keys = ALLOWED_KEYS - OPTIONAL_KEYS
    settings_hash.each do |key, config|
      assert (config.keys - mandatory_keys).empty?, "Missing keys in the settings config for #{key}"
    end
  end
end
