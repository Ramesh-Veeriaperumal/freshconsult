class Email::SettingsDelegator < BaseDelegator

  validate :valid_settings_to_toggle?, on: :update

  def initialize(record, options = {})
    @settings = options
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
  end

  def valid_settings_to_toggle?
    @settings.each_key do |setting|
      unless Account.current.admin_setting_for_account?(EmailSettingsConstants::EMAIL_SETTINGS_PARAMS_NAME_CHANGES[setting.to_sym] || setting.to_sym)
        errors[setting.to_sym] << :require_feature
        error_options.merge!(setting.to_sym => { feature: setting })
      end
    end
  end
end