module Channel::OmniChannelRouting
  class AgentsController < ::ApiAgentsController
    include ChannelAuthentication
    include ::OmniChannelRouting::Util

    SLAVE_ACTIONS = %w(index task_load).freeze

    AGENT_UPDATE_FIELDS = %i[availability].freeze

    skip_before_filter :check_privilege, :verify_authenticity_token
    before_filter :log_request_header, :channel_client_authentication

    def update
      @item.ocr_update = true
      super
    end

    def task_load
      status_ids = []
      current_account.ticket_status_values_from_cache.each do |status|
        status_ids << status.status_id unless status.stop_sla_timer
      end
      count = @item.tickets.visible.sla_on_tickets(status_ids).count
      @response_hash = { agent_id: params[:id].to_i, task_load: count }
    end

    def self.wrap_params
      [:agent, exclude: [], format: [:json]]
    end

    private

      def load_objects(items = scoper)
        items.sort_by { |x| x.name.downcase }
        @items_count = items.count if private_api?
        @items = items
      end

      def after_load_object
      end

      def validate_params
        params[cname].permit(*AGENT_UPDATE_FIELDS)
      end

      def sanitize_params
        params[cname][:available] = params[cname].delete(:availability) if params[cname].key?(:availability)
        super
      end

      def scoper
        agents_scoper = current_account.agents
        return agents_scoper unless index?
        
        agents_scoper.preload(:user)
      end

      wrap_parameters(*wrap_params)
  end
end
