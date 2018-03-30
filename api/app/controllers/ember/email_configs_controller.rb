module Ember
  class EmailConfigsController < ::ApiEmailConfigsController
    decorate_views(decorate_objects: [:search])
    before_filter :validate_search_params, only: [:search] 

    def index
      super
      response.api_meta = { count: @items_count }
    end

    def search
      @items = current_account.email_configs.where(["(reply_email LIKE ? OR name LIKE ?)", "%#{params[:term].strip}%", "%#{params[:term].strip}%"])
      response.api_meta = { count: @items.count } 
    end

    private

      def scoper
        super.where(active: true)
      end

      def validate_search_params
        params.permit(:term, :email_config, *ApiConstants::DEFAULT_PARAMS)
      end

      def per_page
        # Temporary hack to make sure more than 30 email configs are fetched
        (params[:per_page] || ApiConstants::EMAIL_CONFIG_PER_PAGE).to_i
      end
  end
end
