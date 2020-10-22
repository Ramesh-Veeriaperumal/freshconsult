# frozen_string_literal: true

class Account < ActiveRecord::Base

  AccountSettings::SettingsConfig.each do |setting, config|
    define_method "#{setting}_enabled?" do
      dependencies_enabled?(setting.to_sym) && has_feature?(setting.to_sym)
    end
  end

  # Redis feature check can be removed once Redis key cleanup is done
  def compose_email_enabled?
    !has_feature?(:compose_email) || ismember?(COMPOSE_EMAIL_ENABLED, self.id)
  end

  # Need to modify methods when we move all LPs to Bitmaps and validate settings throw error for invalid settings
  def admin_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && !settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  def internal_setting_for_account?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    settings_hash && settings_hash[:internal] && has_feature?(settings_hash[:feature_dependency])
  end

  def enabled_admin_settings
    features_list.select { |feature| admin_setting_for_account?(feature) }
  end

  def enabled_internal_settings
    features_list.select { |feature| internal_setting_for_account?(feature) }
  end

  def enabled_features
    features_list.select { |feature| !AccountSettings::SettingsConfig.keys.include?(feature.to_s) }
  end

  # Can remove the valid_setting check once, all settings are migrated from LP to bitmap
  def enable_setting(setting)
    if valid_setting(setting)
      dependencies_enabled?(setting) ? add_feature(setting) : raise_invalid_setting_error(setting)
    elsif Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(setting)
      launch(setting)
      add_feature(setting)
    end
  end

  # Can remove the valid_setting check once, all settings are migrated from LP to bitmap
  def set_setting(setting)
    if valid_setting(setting)
      dependencies_enabled?(setting) ? set_feature(setting) : raise_invalid_setting_error(setting)
    end
  end

  # Can remove the valid_setting check once, all settings are migrated from LP to bitmap
  def disable_setting(setting)
    if valid_setting(setting)
      dependencies_enabled?(setting) ? revoke_feature(setting) : raise_invalid_setting_error(setting)
    elsif Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(setting)
      rollback(setting)
      revoke_feature(setting)
    end
  end

  # Can remove the valid_setting check once, all settings are migrated from LP to bitmap
  def reset_setting(setting)
    if valid_setting(setting)
      dependencies_enabled?(setting) ? reset_feature(setting) : raise_invalid_setting_error(setting)
    end
  end

  def dependencies_enabled?(setting)
    settings_hash = AccountSettings::SettingsConfig[setting]
    if settings_hash.present? && has_feature?(settings_hash[:feature_dependency])
      return settings_hash[:settings_dependency].blank? || self.safe_send("#{settings_hash[:settings_dependency]}_enabled?")
    else
      return false
    end
  end

  private

    # Can be removed once all settings are migrated from LP to bitmap
    def valid_setting(setting)
      AccountSettings::SettingsConfig[setting].present?
    end

    def raise_invalid_setting_error(setting)
      raise "Invalid setting #{setting} for the account"
    end
end
