module Channel::OmniChannelRouting
  class GroupsController < ::ApiGroupsController
    include ChannelAuthentication
    include ::OmniChannelRouting::Util

    SLAVE_ACTIONS = %w(index unassigned_tasks).freeze

    skip_before_filter :check_privilege
    before_filter :log_request_header, :channel_client_authentication

    def index
      load_objects
    end

    def self.decorator_name
      ::GroupDecorator
    end

    def unassigned_tasks
      status_ids = []
      current_account.ticket_status_values_from_cache.each do |status|
        status_ids << status.status_id unless status.stop_sla_timer
      end
      unassigned_tickets = []
      @group.tickets.visible.unassigned.sla_on_tickets(status_ids).find_each(batch_size: 100) do |ticket|
        unassigned_tickets << { id: ticket.display_id, updated_at: (ticket.updated_at.to_f * 1000).to_i }
      end
      @response_hash = { unassigned_tasks: unassigned_tickets }
    end

    private

      def scoper
        current_account.groups_from_cache
      end

      def load_objects(items = scoper)
        items.sort_by { |x| x.name.downcase }
        @items_count = items.count if private_api?
        @items = items
      end

      def load_object
        @group = current_account.groups.find_by_id(params[:id])
      end
  end
end
