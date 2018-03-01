module ChannelIntegrations
  module Commands
    class Processor
      include ChannelIntegrations::Constants
      include ChannelIntegrations::Utils::ClassParser

      def process(payload)
        command = get_command(payload)
        klass = construct_klass(payload)

        if klass
          klass.new.safe_send(command, payload)
        else
          invalid_action_message
        end
      rescue => e
        Rails.logger.debug "Exception in ChannelIntegrationsCmds, #{e.message}"
        default_exception_message
      end

      private

        def construct_klass(payload)
          klass_name = construct_owner_class(payload, :command)
          klass = Module.const_get(klass_name)
          klass.is_a?(Class) ? klass : nil
        rescue => e
          nil
        end
    end
  end
end
