module ChannelIntegrations::Utils
  module ClassParser
    include ChannelIntegrations::Constants

    def get_command(payload)
      payload[:command_name].to_sym
    end

    def klass_method_format(command)
      "receive_#{command}"
    end

    def service_klass_name(payload, action)
      # If it is a command the owner will be the service name.
      service = action == :command ? payload[:owner] : payload[:client]
      class_name = SERVICE_NAME_CLASS_MAPPING[service.to_sym]
      "#{SERVICE_MODULES[action]}::#{class_name}"
    end
  end
end
