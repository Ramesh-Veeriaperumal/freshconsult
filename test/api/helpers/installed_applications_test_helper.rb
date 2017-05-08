module InstalledApplicationsTestHelper
  def installed_application_pattern(app, _output = {})
    {
      id: app.id,
      application_id: app.application_id,
      app_name: app.application.name,
      configs: validate_configs(app),
      app_display_name: app.application.display_name,
      display_option: Integrations::Constants::APPS_DISPLAY_MAPPING[app.application.name]
    }
  end

  def integrated_user_pattern(app, _output = {})
    {
      id: app.id,
      installed_application_id: app.installed_application_id,
      user_id: app.user_id,
      auth_info: validate_auth_hash(app.auth_info),
      remote_user_id: app.remote_user_id
    }
  end

  def validate_configs(app)
    return {} unless app.configs[:inputs].present?
    configs_hash = app.configs[:inputs]
    if app.application.name == 'dropbox'
      return configs_hash
    else
      configs_hash.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
    end
  end

  def validate_auth_hash(auth_info)
    return {} unless auth_info.present?
    auth_info.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
  end

  def create_application(app_name)
    application = Integrations::Application.find_by_name(app_name)
    installed_app = @account.installed_applications.build(application: application)
    if app_name == 'zohocrm'
      installed_app.set_configs(inputs: { 'api_key' => 'cd8947e9c1cbea743ea9057450b0f5c4', 'domain' => 'https://crm.zoho.com' })
    elsif app_name == 'harvest'
      installed_app.set_configs(inputs: { 'title' => 'Harvest',
                                          'domain' => 'starimpact.harvestapp.com',
                                          'harvest_note' => 'Freshdesk Ticket # {{ticket.id}}}' })
    elsif app_name == 'dropbox'
      installed_app.set_configs(inputs: { 'app_key' => '25zkc7ywmf7tnrl' })
    end
    installed_app.save!
    installed_app
  end

  def create_integ_user_credentials(options = {})
    app = Integrations::Application.find_by_name(options[:app_name])
    installed_app = @account.installed_applications.find_by_application_id(app.id)
    user_credential = installed_app.user_credentials.build
    user_credential.account_id = installed_app.account_id
    user_credential.user_id = options[:user_id]
    user_credential.remote_user_id = options[:remote_user_id]
    user_credential.auth_info = options[:auth_info]
    user_credential.save!
    user_credential
  end
end
