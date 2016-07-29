module Integrations
  class CloudElementsDeleteWorker < ::BaseWorker
    include Sidekiq::Worker
    sidekiq_options :queue => :cloud_elements_delete, :retry => 0, :backtrace => true, :failures => :exhausted
    def perform options
      begin
        current_account = Account.current
        options = options.symbolize_keys
        app = Integrations::Application.where(:id => options[:app_id]).first
        installed_app = current_account.installed_applications.build(:application => app )
        obj = IntegrationServices::Services::CloudElementsService.new(installed_app, {}, {:element_instance_id => options[:element_id]})
        Rails.logger.debug "#{app.name}: Receiving Element Instance Id #{options[:element_id]} For delete...."
        obj.receive(:delete_element_instance)
      rescue IntegrationServices::Errors::TimeoutError => timeouterr
        timeout_error = "Account: #{current_account.full_domain}, Id: #{current_account.id}, Timeout error on #{app.name} Uninstall, Element Instance Id: #{options[:element_id]}. Delete Manually in CE - error: #{timeouterr}"
        Rails.logger.error timeout_error
        NewRelic::Agent.notice_error(timeout_error)
        FreshdeskErrorsMailer.error_email(nil, nil, timeouterr, {
          :subject => timeout_error, :recipients => "integration@freshdesk.com"
        })
        raise timeouterr
      rescue Exception => error
        error_log = "Account: #{current_account.full_domain}, Id: #{current_account.id}, Error on #{app.name} Uninstall, Element Instance Id: #{options[:element_id]}. Delete Manually in CE - error: #{error}"
        Rails.logger.error error_log
        NewRelic::Agent.notice_error(error_log)
        FreshdeskErrorsMailer.error_email(nil, nil, error, {
          :subject => error_log, :recipients => "integration@freshdesk.com"
        })
        raise error
      end
    end
  end
end