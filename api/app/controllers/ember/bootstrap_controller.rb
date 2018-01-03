module Ember
  class BootstrapController < ApiApplicationController
    include Livechat::Token
    COLLECTION_RESPONSE_FOR = [].freeze

    def index

      response.api_meta = construct_api_meta
    end

    private

      # TODO double check the condition for chat enabled and update here if necessary
      def generate_livechat_token
        return {} unless current_account.chat_setting
        {
          livechat_token: livechat_token(current_account.chat_setting.site_id,
                                         current_user.id)
        }
      end


      def construct_api_meta
        api_meta = {
          csrf_token: send(:form_authenticity_token)
        }
        api_meta[:collision_url] = agentcollision_alb_socket_host if current_account.features?(:collision)
        api_meta[:autorefresh_url] = autorefresh_alb_socket_host if current_account.auto_refresh_enabled?
        api_meta[:freshid_url] = Freshid::Constants::FRESHID_CACHE_IMAGE_URL if current_account.freshid_enabled?
        api_meta.merge(generate_livechat_token)
      end
  end
end
