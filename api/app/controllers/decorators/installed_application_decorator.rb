class InstalledApplicationDecorator < ApiDecorator
  delegate :id, :application_id, :configs, :application, :configs, to: :record

  def to_hash
    {
      id: id,
      application_id: application_id,
      app_name: application.name,
      configs: configs_hash,
      app_display_name: application.display_name,
      display_option: Integrations::Constants::APPS_DISPLAY_MAPPING[record.application.name]
    }
  end

  def configs_hash
    return {} unless configs[:inputs].present?
    configs_hash = configs[:inputs]
    # For Dropbox - we need to pass the authkey for loading the chooser
    if Integrations::Constants::ATTACHMENT_APPS.include?(application.name)
      return configs_hash
    else
      configs_hash.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
    end
  end
end
