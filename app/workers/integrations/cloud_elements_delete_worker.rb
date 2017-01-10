require "#{Rails.root}/lib/integration_services/services/cloud_elements_service.rb"

module Integrations
  class CloudElementsDeleteWorker < ::BaseWorker
    include Sidekiq::Worker
    sidekiq_options :queue => :cloud_elements_delete, :retry => 0, :backtrace => true, :failures => :exhausted
    def perform options
      begin
        current_account = Account.current
        options = options.symbolize_keys
        options[:metadata] = options[:metadata].symbolize_keys
        app = Integrations::Application.where(:id => options[:app_id]).first
        installed_app = current_account.installed_applications.build(:application => app )
        obj = IntegrationServices::Services::CloudElementsService.new(installed_app, {}, options[:metadata])
        Rails.logger.debug "#{app.name}: Receiving #{options[:object]} Instance Id #{options[:id]} For delete...."
        response = (options[:object]== Integrations::CloudElements::Constant::NOTATIONS[:element]) ? obj.receive(:delete_element_instance) : obj.receive(:delete_formula_instance)
      rescue Exception => error
        error_log = if options[:object] == Integrations::CloudElements::Constant::NOTATIONS[:element]
          "Account: #{current_account.full_domain}, Id: #{current_account.id}, Error on #{app.name} Uninstall, Element Instance Id: #{options[:metadata][:id]}. Delete Manually in CE - error: #{error}"
        else
          "Account: #{current_account.full_domain}, Id: #{current_account.id}, Error on #{app.name} Uninstall, Formula Instance Id: #{options[:metadata][:id]}, Formula Template Id: #{options[:metadata][:formula_template_id]}. Delete Manually in CE - error: #{error}"
        end
        Rails.logger.error error_log
        NewRelic::Agent.notice_error(error_log)
        FreshdeskErrorsMailer.error_email(nil, nil, error, {
          :subject => error_log, :recipients => AppConfig['integrations_email']
        })
        raise error
      end
    end
  end
end