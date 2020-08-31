module Channel::OmniChannelRouting
  class TicketsController < ApiApplicationController
    include ChannelAuthentication
    include HelperConcern
    include ::OmniChannelRouting::Util

    skip_before_filter :check_privilege, :verify_authenticity_token
    before_filter :log_request_header, :channel_client_authentication

    def assign
      return unless validate_body_params
      @assignment = false
      if verify_current_state?
        @item.responder_id = params[cname][:agent_id]
        return unless validate_delegator(@item)
        @item.set_round_robin_activity
        @item.ocr_update = true
        @assignment = true
        render_errors(@item.errors) unless @item.save
      end
    end

    private

      def load_object
        @item = current_account.tickets.find_by_display_id(params[:id])
        log_and_render_404 unless @item
      end

      def verify_current_state?
        @item.rr_active? && params[cname][:current_state][:group_id] == @item.group_id && @item.responder_id.nil?
      end

      def constants_class
        'Channel::OmniChannelRouting::TicketConstants'.freeze
      end
  end
end
