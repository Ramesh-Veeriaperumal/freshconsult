module Email
  class SettingsController < ApiApplicationController
    skip_before_filter :load_object
    before_filter :validate_settings, only: [:update]
    include HelperConcern
    include Redis::RedisKeys
    include Redis::OthersRedis

    def update
      features = params[cname]
      features.each do |feature, enable|
        feature_name = EmailSettingsConstants::EMAIL_SETTINGS_PARAMS_MAPPING[feature.to_sym] || feature.to_sym
        if feature_name.eql? EmailSettingsConstants::COMPOSE_EMAIL_FEATURE
          toggle_compose_email_feature(feature_name, enable)
        elsif feature_name.eql? EmailSettingsConstants::DISABLE_AGENT_FORWARD
          toggle_disable_email_feature(feature_name, enable)
        elsif check_feature_toggled feature_name, enable
          AccountSettings::SettingsConfig[feature_name] ? toggle_settings(feature_name, enable) : toggle_feature(feature_name, enable)
        end
      end
      generate_view_hash
    end

    def show
      generate_view_hash
    end

    private

      def check_feature_toggled(feature, enable)
        enable != current_account.has_feature?(feature)
      end

      def toggle_feature(feature, enable)
        if enable
          current_account.add_feature(feature)
        else
          current_account.revoke_feature(feature)
        end
      end

      def toggle_settings(setting, enable)
        enable ? current_account.enable_setting(setting) : current_account.disable_setting(setting)
      end

      def toggle_compose_email_feature(feature, enable)
        if enable != check_compose_email_enabled?
          if enable
            current_account.revoke_feature(feature)
          else
            current_account.add_feature(feature)
            $redis_others.perform_redis_op('srem', COMPOSE_EMAIL_ENABLED, current_account.id)
          end
        end
      end

      def toggle_disable_email_feature(feature, enable)
        if enable == current_account.has_feature?(EmailSettingsConstants::DISABLE_AGENT_FORWARD)
          if enable
            current_account.revoke_feature(feature)
          else
            current_account.add_feature(feature)
          end
        end
      end

      def constants_class
        EmailSettingsConstants.to_s.freeze
      end

      def validate_params
        # If block can be removed after LP cleanup
        if !current_account.email_new_settings_enabled?
          field = EmailSettingsConstants::UPDATE_FIELDS_WITHOUT_NEW_SETTINGS
          params[cname].permit(*field)
          @validator = SettingsValidation.new(params[cname], nil, string_request_params?)
          valid = @validator.valid?(action_name.to_sym)
          render_custom_errors(@validator, true) unless valid
          valid
        else
          validate_body_params
        end
      end

      def validate_settings
        params[cname].each_key do |setting|
          setting_hash = AccountSettings::SettingsConfig[EmailSettingsConstants::EMAIL_SETTINGS_PARAMS_MAPPING[setting.to_sym] || setting.to_sym]
          next if !setting_hash || current_account.has_feature?(setting_hash[:feature_dependency])

          return render_request_error(:require_feature, 403, feature: setting)
        end
      end

      def check_compose_email_enabled?
        !current_account.has_features?(EmailSettingsConstants::COMPOSE_EMAIL_FEATURE) || ismember?(COMPOSE_EMAIL_ENABLED, current_account.id)
      end

      def generate_view_hash
        @item = {
          personalized_email_replies: current_account.has_feature?(:personalized_email_replies),
          create_requester_using_reply_to: current_account.has_feature?(:reply_to_based_tickets),
          allow_agent_to_initiate_conversation: check_compose_email_enabled?,
          original_sender_as_requester_for_forward: !current_account.has_feature?(:disable_agent_forward)
        }
        if current_account.email_new_settings_enabled?
          @item[:allow_wildcard_ticket_create] = current_account.allow_wildcard_ticket_create_enabled?
          @item[:skip_ticket_threading] = current_account.skip_ticket_threading_enabled?
        end
      end
  end
end
