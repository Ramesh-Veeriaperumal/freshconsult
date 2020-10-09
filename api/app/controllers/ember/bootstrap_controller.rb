module Ember
  class BootstrapController < ApiApplicationController
    include Livechat::Token
    include Freshid::ControllerMethods

    skip_before_filter :load_object
    COLLECTION_RESPONSE_FOR = [].freeze

    def index
      response.api_meta = construct_api_meta
    end

    def me
      response.api_root_key = :agent
      response.api_meta = construct_api_meta
    end

    def account
      response.api_root_key = :bootstrap
    end

    private

      # TODO double check the condition for chat enabled and update here if necessary
      def generate_livechat_token
        return {} unless current_account.chat_setting
        {
          livechat_token: livechat_token(current_account.chat_setting.site_id,
                                         current_user.id, current_user.privilege?(:admin_tasks))
        }
      end

      def generate_marketplace_token
        jwt_payload = {
          product: Marketplace::Constants::PRODUCT_NAME,
          account_id: current_account.id.to_s,
          domain: current_account.full_domain,
          organisation_id: current_account.organisation_id.to_s,
          time: Time.now.to_i,
          user: {
            id: current_user.id.to_s,
            is_admin: current_user.privilege?(:admin_tasks)
          }
        }

        JWT.encode(jwt_payload, MarketplaceConfig::JWT_SECRET, 'HS256')
      end

      def generate_ask_nicely_hash
        {
          asknicely_user_email_hash: OpenSSL::HMAC.hexdigest('sha256', AskNicelyConfig['hash_token'], current_user.email)
        }
      end

      def construct_api_meta
        api_meta = {
          csrf_token: safe_send(:form_authenticity_token),
          marketplace_auth_token: generate_marketplace_token
        }
        api_meta[:iris_notification_url] = IrisNotificationsConfig["collector_host"]
        api_meta[:collision_url] = agentcollision_alb_socket_host if current_account.features?(:collision)
        api_meta[:autorefresh_url] = autorefresh_alb_socket_host if current_account.auto_refresh_enabled?
        if current_account.freshid_enabled?
          api_meta[:freshid_url] = Freshid::Constants::FRESHID_CACHE_IMAGE_URL
          api_meta[:freshid_profile_url] = freshid_profile_url
        end

        api_meta.merge!(generate_livechat_token)
        api_meta.merge!(generate_ask_nicely_hash) if current_user.privilege?(:admin_tasks) || current_user.privilege?(:manage_account)
        api_meta
      end
  end
end
