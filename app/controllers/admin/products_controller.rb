class Admin::ProductsController < Admin::AdminController
	include ModelControllerMethods
  
  before_filter { |c| c.requires_feature :multi_product }
  before_filter :load_other_objects, :only => [:new, :edit]
  
  # def create
  #   
  # end
  
  protected
    def scoper
      current_account.products
    end

    def build_object
      @obj = @product = current_account.all_email_configs.build(params[:product])
    end

    def create_error
      load_other_objects
    end

    def update_error
      load_other_objects
    end
    
    def load_other_objects
      @groups = current_account.groups
      @solution_categories = current_account.solution_categories
      @forums_categories = current_account.forum_categories
      @product.build_portal unless @product.portal
    end
end
