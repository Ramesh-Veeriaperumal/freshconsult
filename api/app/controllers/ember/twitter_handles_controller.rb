module Ember
  class TwitterHandlesController < ApiApplicationController
    skip_before_filter :check_privilege

    def load_objects
      @items = current_account.twitter_handles
    end

    def check_following
      @error_message, @following = ::Social::Twitter::Feed.following?(@item, params[:screen_name])
      render_base_error(:unable_to_connect_twitter, 424) if @error_message
    end

    private

      def load_object
        @item = current_account.twitter_handles.find(params[:id])
        log_and_render_404 unless @item
      end
  end
end
