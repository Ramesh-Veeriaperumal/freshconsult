module Ember
  module Admin
    class OnboardingController < ApiApplicationController
      include HelperConcern
      include ::Freshcaller::Util
      include ::Freshchat::Util
      include ::Onboarding::OnboardingHelperMethods

      before_filter :validate_body_params, only: [:update_activation_email, :update_channel_config, :test_email_forwarding, :anonymous_to_trial]
      before_filter :validate_query_params, only: [:forward_email_confirmation]
      before_filter :set_user_email_config, only: [:update_activation_email]
      before_filter :check_forward_verification_email_ticket, only: [:forward_email_confirmation]
      before_filter :construct_domain_name, only: [:customize_domain, :validate_domain_name]
      after_filter :unmark_support_email, only: [:customize_domain]

      def update_activation_email
        @item.email = @user_email_config[:new_email]
        @item.keep_user_active = true
        ActiveRecord::Base.transaction do
          update_account_config if @item.save!
        end
        if current_user.active_freshid_agent?
          current_user.reset_persistence_token!
        end
        head 204
      rescue StandardError
        render_errors(@item.errors) if @item.errors.present?
      end

      def update_channel_config
        return unless validate_delegator(nil, cname_params)

        channel = params[cname][:channel]
        @channel_update_response = safe_send("enable_#{channel}_channel_feature")
        return render_response_error if render_error?

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
        @item.enqueue_activation_email
        head 204
      end

      def test_email_forwarding
        if first_attempt?
          EmailConfigNotifier.send_email(:test_email, nil, current_email_config, params[:send_to])
          head 204
        elsif forwarding_success?
          @test_email_forwarding = { ticket_display_id: @forward_test_ticket.display_id }
        else
          head 204
        end
      end

      def validate_domain_name
        head 204 if validate_delegator(@item, new_domain: @full_domain)
      end

      def suggest_domains
        domains = DomainGenerator.sample(current_account.admin_email, 3)
        @suggest_domains = { subdomains: domains }
      end

      def customize_domain
        return unless validate_delegator(@item, new_domain: @full_domain)
        @support_email_configured = current_account.support_email_setup?
        if current_account.update_default_domain_and_email_config(params[:subdomain])
          propagate_new_domain_to_freshcaller if current_account.freshcaller_account.present?
          current_account.mark_customize_domain_setup_and_save
        end
      end

      def anonymous_to_trial
        admin_email_param = params[cname]['admin_email']
        return unless validate_delegator(@item, email: admin_email_param)

        ActiveRecord::Base.transaction do
          current_account.is_anonymous_account = false
          update_admin_related_info(admin_email_param)
          update_current_user_info(admin_email_param)
          convert_to_trial
          enable_external_services(admin_email_param)
        end
        response.api_root_key = :account_configs
      rescue StandardError => e
        current_account.reload
        error_msg = "Error while activating the anonymous account :: ID :: #{@item.id} :: Message :: #{e.message} :: Backtrace :: #{e.backtrace[0..20]}"
        Rails.logger.error(error_msg)
        if @item.errors.present?
          render_errors(@item.errors)
        else
          render_base_error(:internal_error, 500)
        end
      end

      private

        def enable_forums_channel_feature
          current_account.enable_forums_channel
        end

        def enable_social_channel_feature
          current_account.enable_social_channel
        end

        def enable_freshchat_channel_feature
          enable_freshchat_feature
        end

        def enable_phone_channel_feature
          enable_freshcaller_feature
        end

        def render_error?
          if OnboardingConstants::ACCOUNT_CREATION_CHANNELS.include?(params[cname][:channel])
            case params[cname][:channel].to_sym
            when :freshchat
              @channel_update_response.code != 200 || @channel_update_response.try(:[], 'errorCode').present?
            when :phone
              @channel_update_response.code != 200 || @channel_update_response['errors'].present?
            end
          end
        end

        def render_response_error
          case params[cname][:channel].to_sym
          when :freshchat
            render_request_error(freshchat_error_code(@channel_update_response['errorCode']), 409)
          when :phone
            render_request_error(freshcaller_error_code(@channel_update_response['errors']), 409)
          end
        end

        def freshchat_error_code(error)
          error_code = :fchat_link_error
          return error_code if error.blank?
          case error
          when OnboardingConstants::FRESHCHAT_ALREADY_LOGIN
            error_code = :fchat_account_logged_in
          when OnboardingConstants::FRESHCHAT_ACCOUNT_PRESENT
            error_code = :fchat_account_already_presennt
          end
          error_code
        end

        def freshcaller_error_code(error)
          error_code = :fcaller_link_error
          return error_code if error.blank?
          if error['spam_email']
            error_code = :fcaller_spam_email
          elsif error['domain_taken']
            error_code = :fcaller_domain_taken
          end
          error_code
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
          @forward_verification_email_ticket ||= current_account.tickets.requester_latest_tickets(forward_verification_email_requester, params[:requested_time]).first
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

        def construct_domain_name
          params[:subdomain].downcase!
          @full_domain = params[:subdomain] + "." + AppConfig['base_domain'][Rails.env]
        end

        def unmark_support_email
          current_account.unmark_support_email_setup_and_save unless @support_email_configured
        end
    end
  end
end
