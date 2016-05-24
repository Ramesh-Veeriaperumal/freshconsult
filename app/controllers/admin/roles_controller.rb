class Admin::RolesController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :custom_roles }
  
  before_filter :load_object, :only => [ :show, :edit, :update, :destroy, :update_agents ]
  before_filter :check_default, :only => [ :update, :destroy ]
  before_filter :check_users, :only => :destroy

  def index
    @roles = scoper.all.paginate(:page => params[:page], :per_page => 30)
    respond_to do |format|
      format.html
      format.any(:xml, :json) { render request.format.to_sym => @roles }
    end
  end
  
  def show
    redirect_to edit_admin_role_path(@role)
  end
  
  def new
    @role = scoper.new
  end
  
  def create
    if build_and_save
      flash[:notice] = t(:'flash.roles.create.success', :name => @role.name)
      update_role
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
    update_role
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

  def profile_image 
    profile_images = []
    current_account.technicians.preload(:avatar).each do |user|
       profile_images << {:user_id => user.id , :profile_img => user.avatar.nil? ? false : user.avatar.expiring_url(:thumb, 300)}
    end
    render json: profile_images
  end

  def users_list
    users = []
    role_users = params[:id] ? scoper.find_by_id(params[:id]).try(:users) : current_account.technicians
    if role_users
      role_users.each do |user|
        users << {:user_id => user.id, :role_ids => user.role_ids}
      end
    end
    render json: users
  end

  def update_agents
      update_role
      render :json => {:status => true}
  end

  private

    def scoper
      current_account.roles
    end

    def update_role 
      # To avoid account_admin's user_id inject.  
      account_admin = current_account.technicians.find_by_email(current_account.admin_email)
      params_add_user_ids = params[:add_user_ids].split(',') if params[:add_user_ids]
      params_delete_user_ids = params[:delete_user_ids].split(',') if params[:delete_user_ids]
      add_user_ids = (params_add_user_ids || []) - [account_admin.try(:id).to_s]
      delete_user_ids = (params_delete_user_ids || []) - [account_admin.try(:id).to_s]
      update_role_ids( add_user_ids, true)
      update_role_ids( delete_user_ids)
    end

   def update_role_ids list, add = false
     valid_users = current_account.technicians.where(:id => list)
     valid_users.each do |user|
         new_role_ids = add ? user.role_ids.push(@role.id) : user.role_ids - [@role.id]
         user.update_attributes({"role_ids" => new_role_ids })
     end
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