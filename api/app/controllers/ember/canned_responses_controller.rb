module Ember
  class CannedResponsesController < ApiApplicationController

    before_filter :canned_response_permission?, only: [:show]
    before_filter :filter_ids, only: :index
    
    MAX_IDS_COUNT = 10
    
    private

      def validate_filter_params
        params.permit(*ApiConstants::DEFAULT_INDEX_FIELDS, :ids)
      end

      def load_objects
        @items = scoper.where(id: @ids)
        @items.select!(&:visible_to_me?)

        # Instead of using validation to give 4xx response for bad ids,
        # we are going to tolerate and send response for the good ones alone.
        # Because the primary use case for this is Recently used Canned Responses
        log_and_render_404 if @items.blank?
      end
      
      def filter_ids
        @ids = params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
        log_and_render_404 if @ids.blank?
      end

      def scoper
        current_account.canned_responses.preload(helpdesk_accessible: [:group_accesses, :user_accesses])
      end

      def canned_response_permission?
        render_request_error(:access_denied, 403) unless @item.visible_to_me?
      end

  end
end
