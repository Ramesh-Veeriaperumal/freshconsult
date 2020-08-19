module Channel::V2
  class AgentsController < ::ApiAgentsController
    include ChannelAuthentication
    include CentralLib::CentralResyncHelper

    skip_before_filter :check_privilege, :load_object, only: :sync
    before_filter :channel_client_authentication, :validate_sync_params, only: :sync

    def verify_agent_privilege
      @items = { admin: User.current.privilege?(:admin_tasks),
                 allow_agent_to_change_status: api_current_user.toggle_availability?,
                 supervisor: User.current.privilege?(:manage_availability) }
    end

    def sync
      if resync_worker_limit_reached?(@source)
        head 429
      else
        persist_job_info_and_start_entity_publish(@source, request.uuid, 'Agent', @args[:meta], nil, @args[:primary_key_offset])
        @response = { job_id: request.uuid }
        render status: 202
      end
    end

    def validate_sync_params
      @args = params.symbolize_keys
      @errors = []
      @errors.push('meta information is required') if @args[:meta].nil?
      @response = { errors: @errors }
      render status: 400 if @errors.present?
    end
  end
end
