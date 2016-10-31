module Integrations::ContactsSync
  class Base < ::BaseWorker

    sidekiq_options :queue => :contacts_sync, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(app_name, sync_method, meta_data={})
      installed_app = Account.current.installed_applications.with_name(app_name).first
      if installed_app.present?
        service_class = IntegrationServices::Service.get_service_class(app_name)
        if sync_method.to_s == "sync_contacts"
          sync_contacts(app_name, service_class, installed_app)
        else
          sync_contacts_first_time(app_name, service_class, installed_app, meta_data)
        end
      end
    end

    private

      def sync_contacts_first_time( app_name, service_class, installed_app, meta_data)
        sync_account = installed_app.sync_accounts.find(meta_data['sync_account_id'])
        begin
          if sync_account.present? && sync_account.active
            sync_account.update_last_sync_status('in_progress')
            service_obj = service_class.new(installed_app, nil, meta_data)
            service_obj.receive(:sync_contacts_first_time, 36000)
            installed_app.sync_accounts.find(meta_data['sync_account_id']).update_last_sync_status('completed')
          end
        rescue Exception => e
          Rails.logger.error "Error in contacts_sync worker - app_name #{app_name} - \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id, :app_name => app_name, :meta_data => meta_data.to_json } })
          installed_app.sync_accounts.find(meta_data['sync_account_id']).update_last_sync_status("initial_sync_failed")
        end
      end

      def sync_contacts(app_name, service_class, installed_app)
        sync_accounts = installed_app.sync_accounts
        sync_accounts.each do |sync_account|
          next if !sync_account.active
          # first time sync failed
          if sync_account.last_sync_status == "initial_sync_failed"
            meta_data = {'sync_account_id' => sync_account.id}
            sync_contacts_first_time(app_name, service_class, installed_app, meta_data)
          elsif sync_account.last_sync_status != 'progress'
            begin
              sync_account.update_last_sync_status('in_progress')
              meta_data = { 'sync_account_id' => sync_account.id }
              service_class.new(installed_app, nil, meta_data).receive(:sync_contacts, 36000)
              installed_app.sync_accounts.find(sync_account.id).update_last_sync_status('completed')
            rescue Exception => e
              Rails.logger.error "Error in contacts_sync worker - app_name #{app_name} - \n#{e.message}\n#{e.backtrace.join("\n\t")}"
              NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id, :app_name => app_name, :service_class => service_class.to_s, :installed_app => installed_app.to_json } })
              installed_app.sync_accounts.find(sync_account.id).update_last_sync_status("scheduled_sync_failed")
            end
          else
            Rails.logger.info "The previous sync is not yet completed"
          end
        end
      end

  end
end
