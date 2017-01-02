namespace :log_cloud_elements_sync do
  desc "To Create the log for all users who Sync Installed using Cloud Elements"
  task :email_log => :environment do
    Sharding.execute_on_all_shards do
      Rails.logger.info "Cloud Elements Sync Log task Started at #{Time.zone.now}"
      cloud_app_names = Integrations::CloudElements::Constant::APP_NAMES
      apps_query = ["applications.name=?"] * cloud_app_names.size
      apps_query = apps_query.join(" OR ")
      cloud_apps_id = Integrations::Application.where(apps_query, *cloud_app_names).map{|app| app.id}
      installed_apps_query = ["installed_applications.application_id = ?"] * cloud_apps_id.size
      installed_apps_query = installed_apps_query.join(" OR ")
      Integrations::InstalledApplication.where(installed_apps_query, *cloud_apps_id).find_each do |installed_app|
        if installed_app.configs_enable_sync == "on" || (Time.now.utc - installed_app.updated_at.utc) < 1.day # This will be the task running time.
          begin
            installed_app.account.make_current            
            options = {:installed_app_id => installed_app.id}
            Integrations::CloudElementsLoggerEmailWorker.perform_async options
          rescue => e
          ensure
            Account.reset_current_account
          end
        end
      end
      Rails.logger.info "Cloud Elements Sync Log task completed at #{Time.zone.now}"
    end
  end
end
