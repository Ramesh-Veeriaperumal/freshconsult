module ChannelIntegrations::Utils
  module ClassParser
    include ChannelIntegrations::Constants

    def get_command(payload)
      payload[:command_name].to_sym
    end

    def construct_owner_class(payload, action)
      # If it is a command the owner will be the service name.
      service = (action == :command) ? payload[:owner] : payload[:client]
      class_name = SERVICE_NAME_CLASS_MAPPING[service.to_sym]
      "#{SERVICE_MODULES[action]}::#{class_name}"
    end

    # error messages
    def invalid_action_message
      payload = DEFAULT_ERROR_FORMAT
      payload[:data] = {
        message: REPLY_MESSAGES[:invalid_action]
      }
      payload
    end

    def default_exception_message
      payload = DEFAULT_ERROR_FORMAT
      payload[:data] = {
        message: REPLY_MESSAGES[:default_error_message]
      }
      payload
    end
  end
end
