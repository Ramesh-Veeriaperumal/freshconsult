module Ember
  module Admin
    class OnboardingController < ApiApplicationController
      include HelperConcern
      include ::Onboarding::OnboardingHelperMethods

      before_filter :validate_body_params, only: [:update_activation_email, :update_channel_config, :test_email_forwarding]
      before_filter :set_user_email_config, only: [:update_activation_email]
      before_filter :check_onboarding_finished, only: [:update_channel_config]
      before_filter :check_forward_verification_email_ticket, only: [:forward_email_confirmation]

      def update_activation_email
        @item.email = @user_email_config[:new_email]
        @item.keep_user_active = true
        ActiveRecord::Base.transaction do
          if @item.save
            update_account_config
            head 204
          else
            render_errors(@item.errors)
          end
        end
      end

      def update_channel_config
        apply_account_channel_config
        disable_disablable_channels
        complete_admin_onboarding
        head 204
      end

      def forward_email_confirmation
        confirmation_code = (forward_verification_email_ticket.subject.to_s).match(OnboardingConstants::CONFIRMATION_REGEX[email_service_provider])
        @forward_email_confirmation = {
            confirmation_code: confirmation_code.captures.first.to_s,
            email: forward_verification_email_ticket.subject.to_s.match(EMAIL_REGEX).to_s
        }
      end

      def resend_activation_email
        @item.send_activation_email
        head 204
      end

      def test_email_forwarding
        if first_attempt?
          EmailConfigNotifier.test_email(current_email_config, params[:send_to])
          head 204
        elsif forwarding_success?
          @test_email_forwarding = { ticket_display_id: @forward_test_ticket.display_id }
        else
          head 204
        end
      end

      private

        def check_onboarding_finished
          head 404 unless current_account.onboarding_pending?
        end

        def apply_account_channel_config
          channels_config = params[cname][:channels]

          channels_config.each do |channel|
            current_account.safe_send("enable_#{channel}_channel")
          end
        end

        def disable_disablable_channels
          unselected_channels = (OnboardingConstants::CHANNELS - params[cname][:channels])
          disableable_channels = (unselected_channels & OnboardingConstants::DISABLEABLE_CHANNELS)
          disableable_channels.each do |channel|
            current_account.safe_send("disable_#{channel}_channel")
          end
        end

        def constants_class
          :OnboardingConstants.to_s.freeze
        end

        def load_object
          @item = current_user
        end

        def set_user_email_config
          @user_email_config = {
            old_email: @item.email,
            new_email: params[cname][:new_email]
          }
        end

        def update_account_config
          current_account.account_configuration.contact_info[:email] = @user_email_config[:new_email] if current_account.contact_info[:email] == @user_email_config[:old_email]
          current_account.account_configuration.billing_emails[:invoice_emails] = current_account.account_configuration.invoice_emails.map { |x| x == @user_email_config[:old_email] ? @user_email_config[:new_email] : x }
          current_account.account_configuration.save!
        end

        def check_forward_verification_email_ticket
          return head 400 unless OnboardingConstants::VALID_EMAIL_PROVIDERS.include?(email_service_provider)
          head 204 unless forward_verification_email_requester && forward_verification_email_ticket
        end

        def forward_verification_email_requester
          @forward_verification_email_requester ||= current_account.users.find_by_email(OnboardingConstants::FROM_EMAIL[email_service_provider])
        end

        def forward_verification_email_ticket
          @forward_verification_email_ticket ||= current_account.tickets.requester_latest_tickets(forward_verification_email_requester, OnboardingConstants::TICKET_CREATE_DURATION.ago).first
        end

        def email_service_provider
          current_account.email_service_provider
        end

        def first_attempt?
          params[:attempt].to_i == 1
        end

        def current_email_config
          current_portal.main_portal? ? current_account.primary_email_config : current_portal.primary_email_config
        end

        def forwarding_success?
          forward_test_ticket_requester = current_account.users.find_by_email(Helpdesk::EMAIL[:default_requester_email])
          return false unless forward_test_ticket_requester
          @forward_test_ticket = current_account.tickets.requester_latest_tickets(forward_test_ticket_requester, OnboardingConstants::TICKET_CREATE_DURATION.ago).first
          @forward_test_ticket ? (@forward_test_ticket.try(:subject) == OnboardingConstants::TEST_FORWARDING_SUBJECT) : false
        end
    end
  end
end
