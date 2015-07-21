class ApiProductsController < ApiApplicationController

  private

    def scoper
      current_account.products
    end
end
