module Ember
  class EmailConfigsController < ::ApiEmailConfigsController
    def index
      super
      response.api_meta = { count: @items_count }
    end

    private

      def scoper
        super.where(active: true)
      end

      def per_page
        # Temporary hack to make sure more than 30 email configs are fetched
        (params[:per_page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page]).to_i
      end
  end
end
