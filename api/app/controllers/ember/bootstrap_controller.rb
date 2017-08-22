module Ember
  class BootstrapController < ApiApplicationController
    COLLECTION_RESPONSE_FOR = [].freeze

    def index
      response.api_meta = construct_api_meta
    end

    private

      def construct_api_meta
        api_meta = {
          csrf_token: send(:form_authenticity_token)
        }
        api_meta[:collision_url] = agentcollision_alb_socket_host if current_account.features?(:collision)
        api_meta[:autorefresh_url] = autorefresh_alb_socket_host if current_account.auto_refresh_enabled?
        api_meta
      end
  end
end
