module Ember
  module Tickets
    class CollabController < ApiApplicationController
      include TicketConcern
      include HelperConcern

      SLAVE_ACTIONS = %w(notify).freeze
      before_filter :check_feature, only: [:notify]

      def notify
        return unless validate_body_params
        noti_info = {
          mid: params[:mid],
          mbody: params[:body],
          metadata: params[:metadata],
          m_ts: params[:m_ts],
          m_type: params[:m_type],
          top_members: params[:top_members],
          ticket_display_id: params[:id],
          current_domain: host_domain
        }
        CollabNotificationWorker.perform_async(noti_info)
        head :no_content
      end

      private

      def constants_class
        :CollabConstants.to_s.freeze
      end

      def host_domain
        if @ticket.product && @ticket.product.portal_url.present?
          hd = @ticket.product.portal_url
        elsif @current_portal && @current_portal.portal_url.present?
          hd = @current_portal.portal_url
        else
          hd = current_account.host
        end
        hd
      end

      def check_feature
        head :forbidden unless current_account.collaboration_enabled? 
      end

      def check_privilege
        return false unless super # break if there is no enough privilege.
        # TODO: (mayank) Add group_collab usecase here
        # verify_ticket_permission? || (group_collab_enabled? && valid_token?)
        verify_ticket_permission(api_current_user, @ticket) if @ticket
      end

      def scoper
        current_account.tickets
      end

      def load_object
        @ticket = @item = scoper.find_by_display_id(params[:id])
        log_and_render_404 unless @item
      end
    end
  end
end
