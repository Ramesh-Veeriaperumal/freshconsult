# frozen_string_literal: true

module Channel::V2
  class CentralResyncController < ApiApplicationController
    include ChannelAuthentication
    include CentralLib::CentralResyncConstants
    include CentralLib::CentralResyncHelper

    skip_before_filter :check_privilege, if: :skip_privilege_check?
    skip_before_filter :load_object
    before_filter :channel_client_authentication

    def show
      @item = fetch_resync_job_information(source(request.headers['X-Channel-Auth']), params[:id])
      head(404) if @item.blank?
    end

    private

      def skip_privilege_check?
        RESYNC_ALLOWED_SOURCE.each do |source|
          return true if channel_source?(source.to_sym)
        end
        false
      end
  end
end
