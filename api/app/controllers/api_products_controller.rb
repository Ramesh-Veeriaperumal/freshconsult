class ApiProductsController < ApiApplicationController
  private

    def feature_name
      FeatureConstants::PRODUCTS
    end

    def scoper
      current_account.products_from_cache
    end

    def load_object
      @item = scoper.detect { |product| product.id == params[:id].to_i }
      head :not_found unless @item
    end
end
