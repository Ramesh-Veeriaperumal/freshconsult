module Ember
  module Admin
    class OnboardingController < ApiApplicationController
      include HelperConcern
      include Onboarding::OnboardingHelperMethods

      before_filter :validate_body_params, only: [:update_activation_email, :update_channel_config]
      before_filter :set_user_email_config, only: [:update_activation_email]
      before_filter :check_onboarding_finished, only: [:update_channel_config]
      
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

      def resend_activation_email
        @item.send_activation_email
        head 204
      end

      private

        def check_onboarding_finished
          head 404 unless current_account.onboarding_pending?
        end

        def apply_account_channel_config
          channels_config = params[cname][:channels]

          channels_config.each do |channel|
            current_account.send("enable_#{channel}_channel")
          end
        end

        def disable_disablable_channels
          unselected_channels = (OnboardingConstants::CHANNELS - params[cname][:channels])
          disableable_channels = (unselected_channels & OnboardingConstants::DISABLEABLE_CHANNELS)
          disableable_channels.each do |channel|
            current_account.send("disable_#{channel}_channel")
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
    end
  end
end
