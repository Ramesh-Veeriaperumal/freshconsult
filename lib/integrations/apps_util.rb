module Integrations::AppsUtil
  def get_installed_apps
    @installed_applications = Integrations::InstalledApplication.find(:all, :conditions => ["account_id = ?", current_account])
  end
end
