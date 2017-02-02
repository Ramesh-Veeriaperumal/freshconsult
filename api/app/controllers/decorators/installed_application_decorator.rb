class InstalledApplicationDecorator < ApiDecorator
delegate :id, :application_id, :configs, :app_name,  to: :record

def to_hash	
	
  inst_app_hash = {
  	id: record.id,
  	application_id: record.application_id,
  	configs: record.configs[:inputs],
  	app_name: record.application.name,
    app_display_name: record.application.display_name,
    display_option: Integrations::Constants::APPS_DISPLAY_MAPPING[record.application.name]
  }
  inst_app_hash
end
end
