class Admin::ProductsController < Admin::AdminController
  include ModelControllerMethods
  include AccountConstants
  
  before_filter { |c| c.requires_this_feature :multi_product }
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
      if current_account.unlimited_multi_product_enabled? || current_account.products.count < MULTI_PRODUCT_LIMIT
        @obj = @product = current_account.products.build(params[:product])
      else
        flash[:notice] = t(:multi_product_limit)
        redirect_to redirect_url
      end
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
