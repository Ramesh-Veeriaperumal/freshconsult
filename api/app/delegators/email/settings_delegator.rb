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
      unless Account.current.admin_setting_for_account?(EmailSettingsConstants::EMAIL_CONFIG_PARAMS[setting.to_sym] || setting.to_sym)
        errors[:name] << :require_feature
        @error_options[:feature] = setting
      end
    end
  end
end