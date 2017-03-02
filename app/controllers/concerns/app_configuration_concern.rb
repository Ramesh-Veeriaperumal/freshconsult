module Concerns::AppConfigurationConcern
  extend ActiveSupport::Concern

  def get_app_config(app_name)
    installed_app = get_app_details(app_name)
    return installed_app.configs[:inputs] unless installed_app.blank?
  end

  def is_application_installed?(app_name)
    get_app_details(app_name).present?
  end

  def get_app_details(app_name)
    installed_app = installed_apps[app_name.to_sym]
    return installed_app
  end

  def installed_apps
    @installed_apps ||= current_account.installed_apps_hash
  end
end
