module ChannelIntegrations
  module Commands
    class Processor
      include ChannelIntegrations::Constants
      include ChannelIntegrations::Utils::ClassParser

      def process(payload)
        command = get_command(payload)
        klass_instance, perform = service_klass_instance(payload, command)
        raise 'Could not find matching class for command: #{command}' if klass_instance.blank?

        klass_instance.safe_send(perform, payload)
      rescue StandardError => e
        Rails.logger.debug "Exception in ChannelIntegrationsCmds, #{e.message}"
        # The individual services has to catch their errors. If not we will raise and retry again in SQS.
        raise e
      end

      private

        def service_klass_instance(payload, command)
          common_module_name = COMMON_COMMANDS_MODULES_MAPPING[command]
          klass_name = service_klass_name(payload, :command)
          klass = klass_name.constantize

          if service_klass_exists?(klass, command)
            [klass.new, klass_method_format(command).to_sym]
          elsif common_module_name.present?
            [common_module_name.constantize, command]
          end
        end

        def service_klass_exists?(klass, command)
          klass && klass.is_a?(Class) && klass.method_defined?(klass_method_format(command).to_sym)
        end
    end
  end
end
