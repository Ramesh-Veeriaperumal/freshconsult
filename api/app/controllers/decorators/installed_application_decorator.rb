class InstalledApplicationDecorator < ApiDecorator

delegate :id, :application_id, :configs, :app_name, :configs,  to: :record

def to_hash 
  
  inst_app_hash = {
    id: record.id,
    application_id: record.application_id,
    app_name: record.application.name,
    configs: configs_hash,
    app_display_name: record.application.display_name,
    display_option: Integrations::Constants::APPS_DISPLAY_MAPPING[record.application.name]
  }
  inst_app_hash
end

def configs_hash
  return {} unless record.configs[:inputs].present?
  configsHash = record.configs[:inputs]
  configsHash.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH) 
end

end
