module Email
  class SettingsController < ApiApplicationController
    skip_before_filter :load_object
    before_filter :validate_settings, only: [:update]
    include HelperConcern
    include Redis::RedisKeys
    include Redis::OthersRedis
    include EmailSettingsConstants

    def update
      settings = params[cname]
      settings.each do |setting, enable|
        setting_name = EMAIL_SETTINGS_PARAMS_MAPPING[setting.to_sym] || setting.to_sym
        if setting_name.eql? COMPOSE_EMAIL
          toggle_compose_email_setting(setting_name, enable)
        elsif setting_name.eql? DISABLE_AGENT_FORWARD
          toggle_disable_email_setting(setting_name, enable)
        elsif check_setting_toggled setting_name, enable
          toggle_setting setting_name, enable
        end
        generate_view_hash
      end
    end

    def show
      generate_view_hash
    end

    private

      def check_setting_toggled(setting, enable)
        enable != current_account.has_setting?(setting)
      end

      def toggle_setting(setting, enable)
        enable ? current_account.enable_setting(setting) : current_account.disable_setting(setting)
      end

      def toggle_compose_email_setting(feature, enable)
        if enable != current_account.compose_email_enabled?
          if enable
            current_account.disable_setting(feature)
          else
            current_account.enable_setting(feature)
            $redis_others.perform_redis_op('srem', COMPOSE_EMAIL_ENABLED, current_account.id)
          end
        end
      end

      def toggle_disable_email_setting(feature, enable)
        if enable == current_account.disable_agent_forward_enabled?
          if enable
            current_account.disable_setting(feature)
          else
            current_account.enable_setting(feature)
          end
        end
      end

      def constants_class
        EmailSettingsConstants.to_s.freeze
      end

      def validate_params
        validate_body_params
      end

      def validate_settings
        params[cname].each_key do |setting|
          setting_name = EMAIL_SETTINGS_PARAMS_MAPPING[setting.to_sym] || setting.to_sym
          next if current_account.has_feature?(AccountSettings::SettingsConfig[setting_name][:feature_dependency])
          return render_request_error(:require_feature, 403, feature: setting)
        end
      end

      def generate_view_hash
        @item = {
            personalized_email_replies: current_account.personalized_email_replies_enabled?,
            create_requester_using_reply_to: current_account.reply_to_based_tickets_enabled?,
            allow_agent_to_initiate_conversation: current_account.compose_email_enabled?,
            original_sender_as_requester_for_forward: !current_account.disable_agent_forward_enabled?
        }
      end
  end
end
