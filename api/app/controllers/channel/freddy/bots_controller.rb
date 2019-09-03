module Channel
  module Freddy
    class BotsController < ApiApplicationController
      include ChannelAuthentication
      include Freshchat::Util
      include Redis::PortalRedis

      skip_before_filter :check_privilege, :verify_authenticity_token
      before_filter :channel_client_authentication

      def update
        data = params['bot']
        @item.update_attributes(widget_config: data['widget_config'], name: data['name'], status: data['status'] == 'ENABLE')
        freshchat_account = current_account.freshchat_account
        freshchat_account.update_attributes(portal_widget_enabled: 'true', enabled: true) if data['status'] == 'ENABLE'
        increment_portal_version
        @response_hash = bot_response(freshchat_account)
      end

      private

        def scoper
          @item = current_account.freddy_bots
        end

        def load_object
          @item = current_account.freddy_bots.find_by_cortex_id(params[:id])
        end

        def feature_name
          FeatureConstants::AUTOFAQ
        end

        def bot_response(freshchat_account)
          {
            bot: {
              name: @item.name,
              cortex_id: @item.cortex_id,
              account_id: @item.account_id,
              portal_id: @item.portal_id,
              widget_config: @item.widget_config,
              app_id: freshchat_account.app_id,
              widget_token: freshchat_account.token
            }
          }
        end

        def increment_portal_version
          key = PORTAL_CACHE_VERSION % { account_id: current_account.id }
          increment_portal_redis_version key
        end
    end
  end
end
