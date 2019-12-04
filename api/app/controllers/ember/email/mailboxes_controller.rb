module Ember
  module Email
    class MailboxesController < ::Email::MailboxesController
      before_filter :verify_mailbox_type, only: [:send_test_email, :verify_forward_email]
      before_filter :verify_mailbox_status, only: [:send_test_email]

      def send_test_email
        EmailConfigNotifier.test_email(@item)
        head 204
      end

      def verify_forward_email
        render_request_error(:forwarding_ticket_not_found, 404) && return if forwarding_latest_tickets.blank?
        @item.active = true
        @item.save
        @verify_forward_email = {
          ticket_display_id: forwarding_latest_tickets.display_id
        }
      end

      private

        def verify_mailbox_type
          render_request_error(:invalid_custom_mailbox_verification, 412) if custom_mailbox?
        end

        def verify_mailbox_status
          render_request_error(:active_mailbox_verification, 412) if @item.active?
        end

        def forward_test_ticket_requester
          @forward_test_ticket_requester ||= current_account.users.find_by_email(
            Helpdesk::EMAIL[:default_requester_email]
          )
        end

        def forwarding_latest_tickets
          return unless forward_test_ticket_requester

          @forwarding_latest_tickets ||= current_account.tickets.forward_setup_latest_tickets(
            forward_test_ticket_requester,
            @item.to_email, TEST_MAIL_VERIFY_DURATION.ago
          ).first
        end
    end
  end
end
