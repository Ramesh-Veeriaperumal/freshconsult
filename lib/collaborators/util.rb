# frozen_string_literal: true

module Collaborators
  module Util
    include Collaborators::Constants
    class << self
      def enable_collaborators
        raise 'Required features not present' unless Account.current.collaborators_enabled?

        Rails.logger.info("Started enabling Collaborators for Account - #{Account.current.id}")
        add_collaborator_agent_type
      rescue StandardError => e
        log_operation_failure('Enable Feature', e)
      end

      def cleanup_collaborators
        raise 'Required features not present' unless Account.current.collaborators_enabled?

        Rails.logger.info("Removing Collaborators for Account - #{Account.current.id}")
        destroy_collaborator_agent_type
      end

      def log_operation_failure(operation, exception)
        error_msg = "Operation - #{operation} failed in Collaborators. Account ID :: #{Account.current.id}, message :: #{exception.message}"
        Rails.logger.error("#{error_msg}, backtrace :: #{exception.backtrace.join("\n")}")
        NewRelic::Agent.notice_error(exception, description: error_msg)
        # msg_param = { account_id: Account.current.id, request_id: Thread.current[:message_uuid], message: exception.message }
        # sns_subject = "[#{operation}][Collaborators][exception][#{Rails.env}] #{exception.message}"
        # notify_collaborators_dev(sns_subject, msg_param)
      end

      private

        def add_collaborator_agent_type
          agent_type = AgentType.create_agent_type(Account.current, Collaborators::Constants::COLLABORATOR)
          raise 'Failed to create collaborator agent type' unless agent_type
        end

        def destroy_collaborator_agent_type
          # Move this to a worker? Also if an account has a lot of collaborators, we need to include sleep + make sure
          # tons of DB calls dont get called in one go.
          #
          # Agent.destroy_agents(Account.current, AgentType.agent_type_id(Collaborators::Constants::COLLABORATOR))
          # AgentType.destroy_agent_type(Account.current, Collaborators::Constants::COLLABORATOR)
        end
    end

    # add more publicly available util methods here
  end
end
