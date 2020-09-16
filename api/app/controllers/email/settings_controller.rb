module Email
  class SettingsController < ApiApplicationController
    skip_before_filter :load_object
    include HelperConcern
    include Redis::RedisKeys
    include Redis::OthersRedis

    def update
      features = params[cname]
      features.each do |feature, enable|
        feature_name = EmailSettingsConstants::EMAIL_CONFIG_PARAMS[feature.to_sym]
        if feature_name.eql? EmailSettingsConstants::COMPOSE_EMAIL_FEATURE
          toggle_compose_email_feature(feature_name, enable)
        elsif feature_name.eql? EmailSettingsConstants::DISABLE_AGENT_FORWARD
          toggle_disable_email_setting(feature_name, enable)
        elsif check_feature_toggled feature_name, enable
          toggle_feature feature_name, enable
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
          current_account.enable_setting(feature)
        else
          current_account.disable_setting(feature)
        end
      end

      def toggle_compose_email_feature(feature, enable)
        if enable != check_compose_email_enabled?
          if enable
            current_account.disable_setting(feature)
          else
            current_account.enable_setting(feature)
            $redis_others.perform_redis_op('srem', COMPOSE_EMAIL_ENABLED, current_account.id)
          end
        end
      end

      def toggle_disable_email_setting(feature, enable)
        if enable == current_account.safe_send("#{EmailSettingsConstants::DISABLE_AGENT_FORWARD}_enabled?")
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

      def check_compose_email_enabled?
        !current_account.safe_send("#{EmailSettingsConstants::COMPOSE_EMAIL_FEATURE}_enabled?") || ismember?(COMPOSE_EMAIL_ENABLED, current_account.id)
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
