class Admin::RolesController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :custom_roles }
  
  before_filter :load_object, :only => [ :show, :edit, :update, :destroy ]
  before_filter :check_default, :only => [ :update, :destroy ]
  before_filter :check_users, :only => :destroy
  
  def index
    @roles = scoper.all
  end
  
  def show
  end
  
  def new
    @role = scoper.new
  end
  
  def create
    if build_and_save
      flash[:notice] = t(:'flash.roles.create.success', :name => @role.name)
      respond_to do |format|
        format.html { redirect_to admin_roles_url }
      end
    else
      respond_to do |format|
        format.html { render :action => :new }
      end
    end
  end
  
  def edit
    # is there going to be a roles show? or edit, for default roles
  end
  
  def update
  	if @role.update_attributes(params[:role])
      flash[:notice] = t(:'flash.roles.update.success', :name => @role.name)
  		respond_to do |format|
        format.html { redirect_to admin_roles_url }
      end
  	else
  		respond_to do |format|
        format.html { render :action => :new }
      end
  	end
  end
  
  def destroy
    @role.destroy
		redirect_to admin_roles_path
  end

  private

    def scoper
      current_account.roles
    end

    def load_object
      @role = scoper.find(params[:id]) 
    end

    def build_and_save
      @role = scoper.build(params[:role])
      @role.save
    end

    def check_default
      if @role.default_role?
        flash[:notice] = t(:'flash.roles.default_roles')
        redirect_to admin_roles_url
      end
    end
    
    def check_users
      unless @role.user_ids.empty?
        flash[:notice] = t(:'flash.roles.delete.not_allowed')
        redirect_to :back
      end
    end
end