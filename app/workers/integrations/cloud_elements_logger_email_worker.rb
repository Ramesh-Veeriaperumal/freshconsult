module Integrations
  class CloudElementsLoggerEmailWorker < ::BaseWorker
    include Sidekiq::Worker
    sidekiq_options :queue => :cloud_elements_logger_email, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform options
      options = options.symbolize_keys
      installed_app = Integrations::InstalledApplication.where(:id => options[:installed_app_id]).first
      type = installed_app.configs_crm_sync_type
      if type.eql? "FD_AND_CRM"   
        installed_app.configs_crm_last_execution_id = write_log installed_app, "crm"
        installed_app.configs_fd_last_execution_id = write_log installed_app, "fd"
      elsif type.eql? "FD_to_CRM"
        installed_app.configs_fd_last_execution_id = write_log installed_app, "fd"
      else
        installed_app.configs_crm_last_execution_id = write_log installed_app, "crm"
      end
      installed_app.save!
    rescue => e
      Rails.logger.debug "Error inside CloudElementsLoggerEmailWorker: #{e}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error inside CloudElementsLoggerEmailWorker Message: #{e}", :account_id => Account.current.id}})
    end

    def write_log installed_app, type
      instance_id, last_execution_id = if type == "crm"
        [installed_app.configs_crm_to_helpdesk_formula_instance, installed_app.configs_crm_last_execution_id]
      else
        [installed_app.configs_helpdesk_to_crm_formula_instance, installed_app.configs_fd_last_execution_id]
      end
      metadata = {:instance_id => instance_id, :page_size => Integrations::CloudElements::Constant::LOG_PAGE_SIZE}
      service_obj = IntegrationServices::Services::CloudElementsService.new(installed_app, {}, metadata)
      execution = service_obj.receive(:get_formula_executions)
      if last_execution_id.present?
        failure_ids =[]
        execution_size = execution.each_with_index do |exec,index|
          break index if exec["id"] == last_execution_id
          failure_ids.push(exec["id"]) if exec["status"] == "failed"
        end
        execution_size = execution.size if execution_size.class.eql? Array
      else
        failure_ids = execution.map{|exec| exec["id"] if exec["status"].eql? "failed"}.compact
        execution_size = execution.size
      end
      failure_reasons ={}
      failure_reasons = get_failure_reason failure_ids, installed_app if failure_ids.size > 0
      send_email installed_app, type, failure_reasons, execution_size
      (execution.first.nil?) ? nil : execution.first["id"]
    end

    def get_failure_reason failure_ids, installed_app
      failure_reasons = {}
      failure_ids.each do |id|
        service_obj = IntegrationServices::Services::CloudElementsService.new(installed_app, {}, {:execution_id => id})
        failure_step_id = service_obj.receive(:get_formula_failure_step_id)
        reason = nil
        if failure_step_id.present?
          service_obj = IntegrationServices::Services::CloudElementsService.new(installed_app, {}, {:step_execution_id => failure_step_id})
          reason = service_obj.receive(:get_formula_failure_reason)
        end
        failure_reasons[id] = reason
      end
      failure_reasons
    end

    def send_email installed_app, type, failure_reasons, size
      app_name = installed_app.configs_app_name
      subject = (type == "crm") ? "#{app_name.capitalize} to Freshdesk Log" : "Freshdesk to #{app_name.capitalize} Log"
      email_list =  Account.current.account_managers.map { |admin|
        admin.email
      }.join(",")
      bcc_recipients = [AppConfig['integrations_email']]
      subdomain = Account.current.domain
      CloudLogMailer.cloud_log_email({
        :subject => subject, :recipients => email_list, :size => size, :failure_reasons => failure_reasons, :subdomain => subdomain, :bcc_recipients => bcc_recipients
      })
    end
  end
end