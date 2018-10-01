module InstalledApplicationsTestHelper
  include CentralLib::Util

  def central_publish_installed_app_pattern(installed_app)
    {
      id: installed_app.id,
      application_id: installed_app.application_id,
      account_id: installed_app.account_id,
      encrypted_configs: encrypt_for_central(installed_app.configs.to_json.to_s, 'installed_application'),
      encryption_key_name: encryption_key_name('installed_application'),
      created_at: installed_app.created_at.try(:utc).try(:iso8601), 
      updated_at: installed_app.updated_at.try(:utc).try(:iso8601)
    }
  end
end
