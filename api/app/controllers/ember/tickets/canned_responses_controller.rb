module Ember
  module Tickets
    class CannedResponsesController < ApiApplicationController
      include TicketConcern

      before_filter :load_ticket, :ticket_permission?, :canned_response_permission?, only: [:show]

      def show
        @evaluated_content = evaluate_content
        @attachments = @ticket.ecommerce? ? [] : @item.attachments_sharable
      end

      private
        def scoper
          current_account.canned_responses
        end

        def tickets_scoper
          current_account.tickets
        end

        def load_ticket
          @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
          log_and_render_404 unless @ticket.present?
        end

        def evaluate_content
          Liquid::Template.parse(@item.content_html).render({ ticket: @ticket, helpdesk_name: @ticket.account.portal_name }.stringify_keys)
        end

        def canned_response_permission?
          render_request_error(:access_denied, 403) unless @item.visible_to_me?
        end
    end
  end
end
