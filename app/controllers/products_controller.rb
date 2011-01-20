class ProductsController < ApplicationController
  include ModelControllerMethods
  
  def new
    @product.forum_category = ForumCategory.new
  end
  
  protected
    def scoper
      current_account.products
    end
end
