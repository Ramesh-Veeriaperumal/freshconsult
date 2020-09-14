class Account < ActiveRecord::Base

  # Need to modify methods when we move all LPs to Bitmaps and validate settings throw error for invalid settings
  def admin_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && !settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  def internal_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  # Move feature dependency check inside the valid_setting once, all Settings migrate to bitmap from LP
  def enable_setting(setting)
    if valid_setting(setting)
      has_feature?(AccountSettings::SettingsConfig[setting][:feature_dependency]) ? add_feature(setting) : raise_invalid_setting_error(setting)
    elsif Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(setting)
      launch(setting)
      add_feature(setting)
    end
  end

  def set_setting(setting)
    if valid_setting(setting)
      has_feature?(AccountSettings::SettingsConfig[setting][:feature_dependency]) ? set_feature(setting) : raise_invalid_setting_error(setting)
    end
  end

  def disable_setting(setting)
    if valid_setting
      has_feature?(AccountSettings::SettingsConfig[setting][:feature_dependency]) ? revoke_feature(setting) : raise_invalid_setting_error(setting)
    elsif Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(setting)
      rollback(setting)
      revoke_feature(setting)
    end
  end

  def reset_setting(setting)
    if valid_setting
      has_feature?(AccountSettings::SettingsConfig[setting][:feature_dependency]) ? reset_feature(setting) : raise_invalid_setting_error(setting)
    end
  end

  private

    def valid_setting(setting)
      AccountSettings::SettingsConfig[setting].present?
    end

    def raise_invalid_setting_error(setting)
      raise "Invalid setting #{setting} for the account"
    end
end
