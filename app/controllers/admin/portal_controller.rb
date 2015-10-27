class Admin::PortalController < Admin::AdminController

  before_filter :set_moderators_list, :only => :update_settings
  before_filter :filter_feature_list, :only => :update_settings
  before_filter :fetch_portal, :only => [:edit, :update, :destroy, :delete_logo, :delete_favicon]
  before_filter :fetch_product, :check_portal, :only => [:enable, :create]
  before_filter :load_other_objects, :only => [:edit, :enable, :update]

  def index
    main_portal_edit unless current_account.features_included?(:multi_product)
    @products = current_account.products.all(:include => :portal).select{ |p| !p.portal_enabled? }
  end
  
  def settings
    @account = current_account
  end

  def create
    @product.enable_portal
    @product.portal_attributes = params[:portal]
    @portal = @product.portal #incase save fails
    if @portal.save
      flash[:notice] = t('flash.portal.create.success', :product_name => @product.name)
      redirect_to redirect_to_url
    else
      flash[:notice] = t('flash.portal.create.failure')
      load_other_objects
      render :action => 'enable'
    end
  end

  def enable
    @portal = @product.build_portal
  end

  def update_settings
    current_account.update_attributes!(params[:account])
    current_portal.save
    flash[:notice] = t(:'flash.portal_settings.update.success')
    redirect_to settings_admin_portal_index_path
  end

  def update
    if @portal.update_attributes(params[:portal])
      flash[:notice] = t('flash.portal.update.success')
      redirect_to redirect_to_url
    else
      flash[:notice] = t('flash.portal.update.failure')
      render :action => 'edit'
    end
  end

  def destroy
    flash[:notice] = !@portal.main_portal && @portal.destroy ? t('flash.portal.destroy.success', :product_name => @portal.product.name) : 
      t('flash.portal.destroy.failure')
    redirect_to admin_portal_index_path
  end
  
  def delete_logo
    delete_icon('logo')    
  end
  
  def delete_favicon
    delete_icon('fav_icon')
  end

  protected

    def set_moderators_list
      old_ids = current_account.forum_moderators.map(&:moderator_id)
      new_ids = (params[:forum_moderators] || []).map(&:to_i)
      unique_ids = new_ids & old_ids
      create_moderators(new_ids - unique_ids)
      destroy_moderators(old_ids - unique_ids)
    end

    def create_moderators(create_ids)
      return unless create_ids.present?
      forum_moderators = current_account.technicians.find(create_ids).map do |user|
        current_account.forum_moderators.new(:moderator_id => user.id)
      end
      current_account.forum_moderators += forum_moderators
    end

    def destroy_moderators(destroy_ids)
      return unless destroy_ids.present?
      ForumModerator.destroy_all({ :moderator_id => destroy_ids, :account_id => current_account.id })
    end

    # move this method to middleware layer. by Suman
    def filter_feature_list
      allowed_features = {}
      params[:account].slice!("features")
      if params[:account] && params[:account][:features]
        filter_features = params[:account][:features]
        Account::ADMIN_CUSTOMER_PORTAL_FEATURES.each do |feature|
          allowed_features[feature] = filter_features[feature] if filter_features[feature]
        end
        params[:account][:features]  = allowed_features
      end
    end

    def fetch_portal
      @portal = current_account.portals.find_by_id(params[:id])
      redirect_to_index(:portal) and return unless @portal
      @product = @portal.product
    end

    def fetch_product
      @product = current_account.products.find_by_id(params[:product])
      redirect_to_index(:product) and return unless @product
    end

     def load_other_objects
      @solution_categories = current_account.solution_category_meta
      @forums_categories = current_account.forum_categories
    end
    
    def delete_icon(icon_type)
      @portal.send(icon_type).destroy
      @portal.save
      redirect_to :back
      # render :text => "success"
    end

    def check_portal
      redirect_to edit_admin_portal_path(@product.portal.id) unless @product.portal.nil?
    end

    def main_portal_edit
      @portal = current_account.main_portal
      load_other_objects
      render :action => "edit"
    end

    def redirect_to_url
      if params[:customize_portal].presence
        admin_portal_template_path((@portal || @product.portal).id)
      else
        params[:redirect_url] || admin_portal_index_path
      end
    end

    def redirect_to_index(obj)
      flash[:notice] = t(:"flash.portal.not_found.#{obj}")
      redirect_to admin_portal_index_path
    end

end
