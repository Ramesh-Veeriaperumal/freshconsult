module Channel
  module Freddy
    class BotsController < ApiApplicationController
      include ChannelAuthentication
      include Freshchat::Util
      include Redis::PortalRedis

      skip_before_filter :check_privilege, :verify_authenticity_token
      before_filter :channel_client_authentication

      def create
        @item.save
        if freshchat_enabled?
          freshchat_account = current_account.freshchat_account
          sync_freshchat(freshchat_account.app_id)
        elsif current_account.freshchat_account
          freshchat_account = current_account.freshchat_account
          freshchat_account.enabled = true
          freshchat_account.save
          sync_freshchat(freshchat_account.app_id)
        else
          freshchat_account = signup
        end
        increment_portal_version
        @response_hash = bot_response(freshchat_account)
      end

      def update
        data = params['bot']
        @item.update_attributes(widget_config: data['widget_config'], name: data['name'], status: true)
        freshchat_account = current_account.freshchat_account
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

        def freshchat_enabled?
          current_account.freshchat_account && current_account.freshchat_account.enabled?
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
              app_id: freshchat_account.app_id
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
