module Email
  class SettingsController < ApiApplicationController
    skip_before_filter :load_object
    include HelperConcern
    include Redis::RedisKeys
    include Redis::OthersRedis
    include EmailSettingsConstants

    def update
      settings = params[cname]
      settings.each do |setting, value|
        setting_name = EMAIL_SETTINGS_PARAMS_NAME_CHANGES[setting.to_sym] || setting.to_sym
        if setting_name.eql? COMPOSE_EMAIL_SETTING
          toggle_compose_email_setting(setting_name, value)
        elsif is_setting_enabled?(setting_name) != value
          toggle_setting setting_name, value
        end
      end
      generate_view_hash
    end

    def show
      generate_view_hash
    end

    private

      def is_setting_enabled?(setting)
        enabled = current_account.has_setting?(setting)
        NEGATION_SETTINGS.include?(setting) ? !enabled : enabled
      end

      def toggle_setting(setting, value)
        if NEGATION_SETTINGS.include?(setting)
          value ? current_account.disable_setting(setting) : current_account.enable_setting(setting)
        else
          value ? current_account.enable_setting(setting) : current_account.disable_setting(setting)
        end
      end

      #  This method can be removed once redis feature check is cleanedup and :compose_email can be added to NEGATION_SETTINGS
      def toggle_compose_email_setting(setting, value)
        if value != check_compose_email_enabled?
          if value
            current_account.disable_setting(setting)
          else
            current_account.enable_setting(setting)
            $redis_others.perform_redis_op('srem', COMPOSE_EMAIL_ENABLED, current_account.id)
          end
        end
      end

      def constants_class
        EmailSettingsConstants.to_s.freeze
      end

      def validate_params
        validate_body_params
        validate_delegator(nil, params[cname])
      end

      def check_compose_email_enabled?
        !current_account.has_setting?(COMPOSE_EMAIL_SETTING) || ismember?(COMPOSE_EMAIL_ENABLED, current_account.id)
      end

      def generate_view_hash
        @item = {
          personalized_email_replies: current_account.personalized_email_replies_enabled?,
          create_requester_using_reply_to: current_account.reply_to_based_tickets_enabled?,
          allow_agent_to_initiate_conversation: check_compose_email_enabled?,
          original_sender_as_requester_for_forward: !current_account.disable_agent_forward_enabled?
        }
      end
  end
end
