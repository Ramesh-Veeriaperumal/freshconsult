module AccountSettings
  SettingsConfig = YAML.load_file(File.join(Rails.root, 'config', 'features', 'settings.yml')).with_indifferent_access[:settings]
  feature_to_settings_mapping = {}
  SettingsConfig.each do |setting, config|
    feature_name = config[:feature_dependency]
    raise StandardError, "Feature not found for the setting #{setting}" if feature_name.nil?

    feature_to_settings_mapping[feature_name] ||= []
    feature_to_settings_mapping[feature_name] << setting
  end
  FeatureToSettingsMapping = feature_to_settings_mapping.freeze
end
