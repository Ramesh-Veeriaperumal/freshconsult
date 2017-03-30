module Ember
  class PortalsController < ApiApplicationController
    decorate_views
    def index
      super
      response.api_meta = { count: @items.size }
    end

    private
      def load_objects
        @items = current_account.portals.all
      end
  end
end
