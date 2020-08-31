module AccountSettings
  SettingsConfig = YAML.load_file(File.join(Rails.root, 'config', 'features', 'settings.yml')).with_indifferent_access[:settings]
  FeatureToSettingsMapping = Hash.new()
  SettingsConfig.each do |setting, config|
    feature_name = config[:feature_dependency]
    raise StandardError, "Feature not found for the setting #{setting}" if feature_name.nil?
    FeatureToSettingsMapping[feature_name] ||= Array.new()
    FeatureToSettingsMapping[feature_name] << setting
  end
end