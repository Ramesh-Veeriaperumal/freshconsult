class Account < ActiveRecord::Base

  def valid_setting_for_account(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && has_feature?(settings_hash[:feature_dependency])
  end

  def admin_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && !settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  def internal_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  def enable_setting(setting)
    valid_setting_for_account ? add_feature(setting) : raise_invalid_setting_error(setting)
  end

  def set_setting(setting)
    valid_setting_for_account ? set_feature(setting) : raise_invalid_setting_error(setting)
  end

  def disable_setting(setting)
    valid_setting_for_account ? revoke_feature(setting) : raise_invalid_setting_error(setting)
  end

  def reset_setting(setting)
    valid_setting_for_account ? reset_feature(setting) : raise_invalid_setting_error(setting)
  end

  private 

    def raise_invalid_setting_error(setting)
      raise RuntimeError, "Invalid setting #{setting} for the account"
    end
end
