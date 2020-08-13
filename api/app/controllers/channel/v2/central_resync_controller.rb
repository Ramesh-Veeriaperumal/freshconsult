# frozen_string_literal: true

module Channel::V2
  class CentralResyncController < ApiApplicationController
    include ChannelAuthentication
    include CentralLib::CentralResyncHelper

    before_filter :channel_client_authentication

    private

      def load_object
        @item = fetch_resync_job_information(@source, params[:id])
        head(404) if @item.blank?
      end
  end
end
