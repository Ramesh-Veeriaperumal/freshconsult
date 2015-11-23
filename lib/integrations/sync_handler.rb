module Integrations
  class SyncHandler
    def execute(data, configs)
      service_name = configs.delete(:service)
      return if data.spam || data.deleted
      service_class = IntegrationServices::Service.get_service_class(service_name)      
      if service_class.present?
        event = configs.delete(:event)
        installed_application = Account.current.installed_applications.with_name(service_name).first
        return unless installed_application.present? && installed_application.configs_salesforce_sync_option.to_s.to_bool
        service_obj = service_class.new installed_application, { :data_object => data }, configs
        service_obj.receive(event)
      end
    end
  end
end
