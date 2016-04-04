class Admin::ProductsController < Admin::AdminController
	include ModelControllerMethods
  
  before_filter { |c| c.requires_feature :multi_product }
  before_filter :build_object, :only => [:new, :create]
  before_filter :load_other_objects, :only => [:new, :edit]
  
  def update
    if @product.update_attributes(params[:product])
      
      flash.now[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)

      redirect_to redirect_url
    else
      update_error
      render :action => 'edit'
    end
    
  end
  
  protected

    def scoper
      current_account.products
    end

    def build_object
      @obj = @product = current_account.products.build(params[:product])
    end

    def create_error
      load_other_objects
    end

    def update_error
      load_other_objects
    end
    
    def load_other_objects
      @groups = current_account.groups
      @portal = @product.portal
      @product.email_configs.build(:primary_role => true) if @product.email_configs.empty?
    end

    def redirect_url
      if params[:enable_portal].nil?
        admin_products_path
      else
        @product.portal.nil? ? enable_admin_portal_index_path(:product => @product.id, :enable => true) : edit_admin_portal_path(@product.portal)
      end
    end
end
