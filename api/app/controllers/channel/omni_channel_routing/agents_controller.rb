module Channel::OmniChannelRouting
  class AgentsController < ::ApiAgentsController
    include ChannelAuthentication
    include ::OmniChannelRouting::Util

    SLAVE_ACTIONS = %w(index task_load).freeze

    skip_before_filter :check_privilege
    before_filter :log_request_header, :channel_client_authentication

    def index
      load_objects
    end

    def load_objects(items = scoper)
      items.sort_by { |x| x.name.downcase }
      @items_count = items.count if private_api?
      @items = items
    end

    def task_load
      status_ids = []
      current_account.ticket_status_values_from_cache.each do |status|
        status_ids << status.status_id unless status.stop_sla_timer
      end
      count =  @agent.tickets.visible.sla_on_tickets(status_ids).count
      @response_hash = { agent_id: params[:id].to_i, task_load: count }
    end

    private

      def scoper
        current_account.agents.preload(:user)
      end

      def load_object
        @agent = current_account.agents.find_by_user_id(params[:id])
      end

  end
end
