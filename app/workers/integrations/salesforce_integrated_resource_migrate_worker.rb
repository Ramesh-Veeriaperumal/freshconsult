module Integrations
  class SalesforceIntegratedResourceMigrateWorker < ::BaseWorker
    include Sidekiq::Worker
    sidekiq_options :queue => :salesforce_integrated_resource_migrate, :retry => 0, :backtrace => true, :failures => :exhausted
    def perform
      begin
        current_account = Account.current
        old_installed_app = current_account.installed_applications.with_name("salesforce").first
        new_installed_app = current_account.installed_applications.with_name("salesforce_v2").first
        return if old_installed_app.nil? || new_installed_app.nil? #Installed app can be nil if app is unistalled before worker is started.
        old_installed_app.integrated_resources.find_each do |int_res|
          new_installed_app.integrated_resources.create(
            :remote_integratable_id => int_res.remote_integratable_id,
            :remote_integratable_type => int_res.remote_integratable_type,
            :local_integratable_id => int_res.local_integratable_id,
            :local_integratable_type => int_res.local_integratable_type,
            :account_id => current_account.id
          )
        end
      rescue Exception => error
      end
    end
  end
end