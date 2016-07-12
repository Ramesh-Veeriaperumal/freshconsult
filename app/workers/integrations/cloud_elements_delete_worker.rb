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
        obj.receive(:delete_element_instance)
      rescue IntegrationServices::Errors::TimeoutError => timeouterr
        timeout_error = "Timeout error on CE elements delete, delete element id #{options[:element_id]} manually - error: #{timeouterr}"
        Rails.logger.debug timeout_error
        NewRelic::Agent.notice_error(timeout_error)
        FreshdeskErrorsMailer.error_email(nil, nil, timeouterr, {
          :subject => timeout_error, :recipients => "integrations@freshesk.com"
        })
        raise timeouterr
      rescue Exception => error
        error_log = "error on CE elements delete, delete element id #{options[:element_id]} manually - error: #{error}"
        Rails.logger.debug error_log
        NewRelic::Agent.notice_error(error_log)
        FreshdeskErrorsMailer.error_email(nil, nil, error, {
          :subject => error_log, :recipients => "integrations@freshesk.com"
        })
        raise error
      end
    end
  end
end