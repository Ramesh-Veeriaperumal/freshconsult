# frozen_string_literal: true

module Channel::V2
  class CentralResyncController < ApiApplicationController
    include ChannelAuthentication
    include CentralLib::CentralResyncHelper

    skip_before_filter :check_privilege, :load_object
    before_filter :channel_client_authentication

    def show
      @item = fetch_resync_job_information(source(request.headers['X-Channel-Auth']), params[:id])
      head(404) if @item.blank?
    end
  end
end
