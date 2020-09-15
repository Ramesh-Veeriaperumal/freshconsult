module Channel::V2
  class AgentsController < ::ApiAgentsController
    include ChannelAuthentication
    include CentralLib::CentralResyncHelper
    include CentralLib::CentralResyncConstants

    skip_before_filter :check_privilege, if: :skip_privilege_check?
    before_filter :channel_client_authentication, :validate_sync_params, only: :sync

    def verify_agent_privilege
      @items = { admin: User.current.privilege?(:admin_tasks),
                 allow_agent_to_change_status: api_current_user.toggle_availability?,
                 supervisor: User.current.privilege?(:manage_availability) }
    end

    def sync
      channel_source = @source
      if resync_worker_limit_reached?(channel_source)
        head 429
      else
        persist_job_info_and_start_entity_publish(channel_source, request.uuid, RESYNC_ENTITIES[:agent], @args[:meta], nil, @args[:primary_key_offset])
        @response = { job_id: request.uuid }
        render status: 202
      end
    end

    private

      def validate_sync_params
        @args = params.symbolize_keys
        agent_validation = Channel::V2::AgentValidation.new(@args)
        render_custom_errors(agent_validation, true) unless agent_validation.valid?(action_name.to_sym)
      end

      def skip_privilege_check?
        RESYNC_ALLOWED_SOURCE.any? { |source| channel_source?(source.to_sym) }
      end
  end
end
