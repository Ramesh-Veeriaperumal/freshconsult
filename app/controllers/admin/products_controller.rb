class Admin::ProductsController < Admin::AdminController
	include ModelControllerMethods
  
  before_filter :only => [:new, :create] do |c|
    c.requires_feature :multi_product
  end
  
  def new
    @groups = current_account.groups
    @solution_categories = current_account.solution_categories
    @forums_categories = current_portal.forum_categories
    @product.build_portal
  end

  def edit
    @groups = current_account.groups
  end

  protected
    def scoper
      current_account.products
    end

    def build_object
      @obj = @product = current_account.all_email_configs.build(params[:product])
    end

    def create_error
      @groups = current_account.groups
    end

    def update_error
      @groups = current_account.groups
    end
end