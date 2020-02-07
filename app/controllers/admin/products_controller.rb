class Admin::ProductsController < Admin::AdminController
  include ModelControllerMethods
  include Email::Mailbox::Utils

  before_filter { |c| c.requires_this_feature :multi_product }
  before_filter :validate_on_update, only: :update
  before_filter :validate_params, only: [:create, :update]
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

    def validate_on_update
      params[:product][:email_configs_attributes].each_value do |value|
        value.except!(:reply_email, :to_email) if value[:id].present?
      end
    end

    def validate_params
      params[:product][:email_configs_attributes].each_value do |value|
        value[:to_email] = construct_to_email(value[:reply_email], current_account.full_domain) if value[:reply_email].present?
      end
    end
end
