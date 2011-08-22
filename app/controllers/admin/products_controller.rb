class Admin::ProductsController < Admin::AdminController
	include ModelControllerMethods
  
  before_filter { |c| c.requires_feature :multi_product }
  before_filter :build_object, :only => :new
  before_filter :load_other_objects, :only => [:new, :edit]
  
  def create
    portal_params = params[:product].delete(:portal_attributes)
    build_object
    
    if @product.portal_enabled?
      @product.build_portal
      @product.portal.account_id = @product.account_id
      @product.portal.attributes = portal_params
    end
    
    super
  end
  
  def update
    portal_params = params[:product].delete(:portal_attributes)
        
    if @product.update_attributes(params[:product])
      post_process_on_update portal_params
      flash.now[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
      redirect_to :action => 'index'
    else
      update_error
      redirect_to :action => 'edit'
    end
    
  end
  
  def delete_logo
    delete_icon('logo')
  end
  
  def delete_fav
    delete_icon('fav_icon')
  end
  
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
    
    def post_process_on_update(portal_params)
      unless @product.portal
        if @product.portal_enabled?
          @product.build_portal
          @product.portal.account_id = @product.account_id
          @product.portal.attributes = portal_params
          @product.portal.save
        end
        return
      end

      @product.portal.update_attributes(portal_params) and return if @product.portal_enabled?
      @product.portal.destroy
    end
    
    def delete_icon(icon_type)
      current_account.portals.find(params[:id]).send(icon_type).destroy
      render :text => "success"
    end
end
