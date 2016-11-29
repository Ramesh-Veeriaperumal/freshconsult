module Ember
  class CannedResponsesController < ApiApplicationController

    before_filter :canned_response_permission?, only: [:show]

    private

      def scoper
        current_account.canned_responses
      end

      def canned_response_permission?
        render_request_error(:access_denied, 403) unless @item.visible_to_me?
      end

  end
end
