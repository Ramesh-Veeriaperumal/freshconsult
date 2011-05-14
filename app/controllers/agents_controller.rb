class AgentsController < Admin::AdminController
  
  before_filter :load_object, :only => [:update,:destroy,:restore,:edit]
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :check_user_permission, :only => :destroy
  before_filter :check_agent_limit, :only => :create
  
  def load_object
    @agent = scoper.find(params[:id])
  end
  
  def check_user_permission
    if (@agent.user == current_user) || (@agent.user.user_role == User::USER_ROLES_KEYS_BY_TOKEN[:account_admin])
      flash[:notice] = "You don't have access to delete it!"
      redirect_to :back  
    end    
  end
  
  def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = "Demo site doesn't have this access!"
      redirect_to :back
    end
  end
    
  def index    
    @agents = current_account.agents.find(:all , :include => :user )
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @agents }
    end
  end

  def show    
    @agent = current_account.all_agents.find(params[:id])
    @user  = @agent.user
    #redirect_to :action => 'edit'
  end

  def new    
    @agent      = current_account.agents.new       
    @agent.user = User.new
    @agent.user.avatar = Helpdesk::Attachment.new
    @agent.user.time_zone = current_account.time_zone
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def edit    
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @agent }
    end    
  end
  
  def delete_avatar
    @user = current_account.all_users.find(params[:id])
    @user.avatar.destroy
    render :text => "success"
  end

  def create   
    
    @user  = current_account.users.new #by Shan need to check later        
    @agent = current_account.agents.new(params[nscname]) 
    
    if @user.signup!(:user => params[:user])       
      @agent.user_id = @user.id      
      if @agent.save
         flash[:notice] = "The Agent has been created and activation instructions sent to #{@user.email}!"
         redirect_to :action => 'index'
      else      
        render :action => :new         
      end
    else       
        check_email_exist
        @agent.user =@user       
        render :action => :new        
    end    
  end

  def update
   
      if @agent.update_attributes(params[nscname])            
          @user = current_account.all_users.find(@agent.user_id)          
          if @user.update_attributes(params[:user])        
             flash[:notice] = "The Agent has been updated sucessfully"
             redirect_to :action => 'index'
         else
             check_email_exist     
             @agent.user =@user       
             render :action => :edit 
         end
      else
        @agent.user =@user       
        render :action => :edit
      end    
     
  end

  def destroy    
    if @agent.user.update_attribute(:deleted, true)    
       @restorable = true
       flash[:notice] = render_to_string(:partial => '/agents/flash/delete_notice')      
     else
           flash[:notice] = "Agent could not be able to delete"           
     end
    redirect_to :back
end

 def restore
   @agent = current_account.all_agents.find(params[:id])
   if @agent.user.update_attribute(:deleted, false)   
    flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
   else
    flash[:notice] = "Agent could not be able to restore"
   end 
   redirect_to :back  
 end

 protected
 
  def scoper
     current_account.all_agents
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def check_email_exist
     if("has already been taken".eql?(@user.errors["email"]))        
           @existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
     end    
  end

  def check_agent_limit
    redirect_to :back if current_account.reached_agent_limit?
  end
end
