module AccountSettings
  SettingsConfig = YAML.load_file(File.join(Rails.root, 'config', 'features', 'settings.yml')).with_indifferent_access[:settings]
  feature_dependency_to_settings_mapping = {}
  setting_dependency_to_settings_mapping = {}
  SettingsConfig.each do |setting, config|
    feature_dependency = config[:feature_dependency]
    settings_dependency = config[:settings_dependency]
    raise StandardError, "Feature not found for the setting #{setting}" if feature_dependency.nil?

    feature_dependency_to_settings_mapping[feature_dependency] ||= []
    feature_dependency_to_settings_mapping[feature_dependency] << setting.to_sym
    next if settings_dependency.blank?
    raise StandardError, "Cyclic dependency between settings #{setting} and #{settings_dependency}" if setting_dependency_to_settings_mapping[setting].present? && setting_dependency_to_settings_mapping[setting].include?(settings_dependency.to_sym)

    setting_dependency_to_settings_mapping[settings_dependency] ||= []
    setting_dependency_to_settings_mapping[settings_dependency] << setting.to_sym
  end
  FeatureToSettingsMapping = feature_dependency_to_settings_mapping.freeze # mapping of feature with all settings which are dependent to it { feature_dependency: [settings] }
  SettingToSettingsMapping = setting_dependency_to_settings_mapping.freeze # mapping of setting with all settings which are dependent to it { settings_dependency: [settings] }
end
