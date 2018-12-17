module Ember
  class OmniChannelsController < ApiApplicationController
    def index
      available_channels
    end

    private

      def available_channels
        @channel = {
          facebook: current_account.facebook_pages.count > 0,
          twitter: current_account.twitter_handles.count > 0,
          freshchat: current_account.freshchat_account.try(:enabled).present?,
          freshcaller: current_account.freshcaller_account.present?
        }
      end
  end
end
