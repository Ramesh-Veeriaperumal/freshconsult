module ChannelIntegrations
  # For every command that a service send it should expect a reply back.
  module Replies
    class Processor
      include ChannelIntegrations::Utils::ClassParser

      def process(payload)
        command = get_command(payload)
        klass = construct_klass(payload)

        klass.new.safe_send(command, payload) if klass
      rescue => e
        Rails.logger.debug "Exception in Processing Replies from Channel, #{e.message}"
      end

      private

        def construct_klass(payload)
          klass_name = construct_owner_class(payload, :reply)
          klass = Module.const_get(klass_name)
          klass.is_a?(Class) ? klass : nil
        rescue => e
          nil
        end
    end
  end
end
