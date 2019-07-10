module ThirdCrm
  config = YAML.load_file(Rails.root.join('config', 'freshmarketer_automation.yml'))
  FRESHMARKETER_CONFIG = config['freshmarketer'][Rails.env]
  AP_VS_FM_DEFAULT_FIELDS = config['freshmarketer'][Rails.env]['default_fields_mapping']
  AP_VS_FM_CUSTOM_FIELDS = config['freshmarketer'][Rails.env]['custom_fields_mapping']
end
