module Ember
  module Email
    class MailboxesController < ::Email::MailboxesController
      include ::Admin::EmailConfig::EmailProvider

      before_filter :verify_mailbox_type, only: [:send_test_email, :verify_forward_email, :email_provider, :email_forward_verification_code]
      before_filter :verify_mailbox_status, only: [:send_test_email]

      def email_provider
        @email_provider = {
          provider: email_domain_service
        }
      end

      def email_forward_verification_code
        if forwarded_activation_ticket.blank?
          render_request_error(:forwarding_ticket_not_found, 404)
          return
        end

        confirmation_code, email = process_confirmation_email
        @email_forward_verification_code = {
          confirmation_code: confirmation_code,
          email: email
        }
      end

      def send_test_email
        EmailConfigNotifier.test_email(@item)
        head 204
      end

      def verify_forward_email
        if forwarding_latest_tickets.blank?
          render_request_error(:forwarding_ticket_not_found, 404)
          return
        end
        @item.active = true
        @item.save
        @verify_forward_email = {
          ticket_display_id: forwarding_latest_tickets.display_id
        }
      end

      private

        def email_domain_service
          provider = get_email_service_name(mailbox_domain) if mailbox_domain
          provider && provider == EMAIL_SERVICE_PROVIDER_GMAIL || EMAIL_SERVICE_PROVIDER_OUTLOOK ? provider : EMAIL_SERVICE_PROVIDER_OTHER
        end

        def mailbox_domain
          @item.reply_email.split('@')[1] if @item && @item.reply_email
        end

        def process_confirmation_email
          ticket = forwarded_activation_ticket
          parsed_confirmation_code = ticket.subject.to_s.match(CONFIRMATION_CODE_REGEX)

          if parsed_confirmation_code.present?
            [parsed_confirmation_code.captures.first.to_s, ticket.subject.to_s.match(EMAIL_REGEX).to_s]
          else
            [parsed_confirmation_code, ticket.subject.to_s.match(EMAIL_REGEX).to_s]
          end
        end

        def forwarded_activation_requester
          @forwarded_activation_requester ||= current_account.all_users.where(email: GMAIL_DEFAULT_REQUESTER).first
        end

        def forwarded_activation_ticket
          return unless forwarded_activation_requester

          @forwarded_activation_ticket ||= current_account.tickets.forward_setup_latest_tickets(
            forwarded_activation_requester,
            @item.to_email, TEST_MAIL_VERIFY_DURATION.ago
          ).first
        end

        def verify_mailbox_type
          render_request_error(:invalid_custom_mailbox_verification, 412) if custom_mailbox?
        end

        def verify_mailbox_status
          render_request_error(:active_mailbox_verification, 412) if @item.active?
        end

        def forward_test_ticket_requester
          @forward_test_ticket_requester ||= current_account.all_users.where(
            email: Helpdesk::EMAIL[:default_requester_email]
          ).first
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
