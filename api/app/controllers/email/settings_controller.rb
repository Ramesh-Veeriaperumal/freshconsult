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
        enabled = current_account.safe_send("#{setting}_enabled?")
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
        if value != current_account.compose_email_enabled?
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
      end

      def validate_settings
        params[cname].each_key do |setting|
          unless Account.current.admin_setting_for_account?(EmailSettingsConstants::EMAIL_SETTINGS_PARAMS_NAME_CHANGES[setting.to_sym] || setting.to_sym)
            return render_request_error(:require_feature, 403, feature: setting)
          end
        end
      end

      def generate_view_hash
        @item = {}
        UPDATE_FIELDS.each do |setting|
          setting_name = EMAIL_SETTINGS_PARAMS_NAME_CHANGES[setting.to_sym] || setting.to_sym
          @item[setting.to_sym] = is_setting_enabled?(setting_name)
        end
      end
  end
end
