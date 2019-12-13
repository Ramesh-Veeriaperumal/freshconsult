module Ember
  class YearInReviewController < ApiApplicationController

    include YearInReviewMethods

    before_filter :check_feature
    skip_before_filter :validate_filter_params
    skip_before_filter :before_load_object, :load_object, :after_load_object

    def index
      @item = fetch_review
    end

    def share
      share_video
      head :no_content
    end

    def clear
      clear_review_box
      head :no_content
    end

    private

      def check_feature
        return if Account.current.year_in_review_and_share_enabled?
        
        render_request_error(:require_feature, 403, feature: "Year In Review")
      end
  end
end
