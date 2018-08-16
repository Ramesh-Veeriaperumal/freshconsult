module Ember
  class FreshconnectController < ApiApplicationController

    skip_before_filter :verify_authenticity_token
    ALLOWED_PARAMS = ['enabled']

    def update
      return unless valid_params
      if @item.update_attributes(enabled: params[:enabled])
        update_freshconnect_feature(params[:enabled])
      else
        render_errors(@item.errors)
      end
    end

    private

      def valid_params
        cname_params.permit(*ALLOWED_PARAMS)
      end

      def update_freshconnect_feature(enabled)
        update_action = enabled ? "add" : "revoke"
        [:freshconnect, :collaboration].each { |item| Account.current.safe_send("#{update_action}_feature", item) }
      end

      def load_object
        @item = ::Freshconnect::Account.find_by_account_id(current_account.id)
        log_and_render_404 unless @item
      end
  end
end
