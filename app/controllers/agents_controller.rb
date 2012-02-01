class AgentsController < Admin::AdminController
  include HandleAdditionalAgent
  
  skip_before_filter :check_account_state, :only => :destroy
  
  before_filter :load_object, :only => [:update,:destroy,:restore,:edit]
  before_filter :update_agent_object, :only => :update
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :check_user_permission, :only => :destroy
  before_filter :build_user_and_agent, :only => [:create]
  before_filter :charge_agent_prorata, :only => [:create,:restore,:update]
  
  def load_object
    @agent = scoper.find(params[:id])
  end
  
  def check_user_permission
    if (@agent.user == current_user) || (@agent.user.user_role == User::USER_ROLES_KEYS_BY_TOKEN[:account_admin])
      flash[:notice] = t(:'flash.agents.delete.not_allowed')
      redirect_to :back  
    end    
  end
  
  def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = t(:'flash.not_allowed_in_demo_site')
      redirect_to :back
    end
  end
    
  def index    
    @agents = current_account.agents.find(:all , :include => :user , :order =>'name').paginate(:page => params[:page], :per_page => 30)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @agents }
    end
  end

  def show    
    @agent = current_account.all_agents.find(params[:id])
    @user  = @agent.user
    @recent_unresolved_tickets = current_account.tickets.assigned_to(@user).unresolved.visible.newest(5)
    #redirect_to :action => 'edit'
  end

  def new    
    @agent      = current_account.agents.new       
    @agent.user = User.new
    @agent.user.avatar = Helpdesk::Attachment.new
    @agent.user.time_zone = current_account.time_zone
    @agent.user.language = current_portal.language
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
    if @user.signup!(:user => params[:user])  
      @agent.user_id = @user.id      
      if @agent.save
         flash[:notice] = t(:'flash.agents.create.success', :email => @user.email)
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
             flash[:notice] = t(:'flash.general.update.success', :human_name => 'Agent')
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
       flash[:notice] = t(:'flash.general.destroy.failure', :human_name => 'Agent')
     end
    redirect_to :back
end

 def restore
   @agent = current_account.all_agents.find(params[:id])
   if @agent.user.update_attribute(:deleted, false)   
    flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
   else
    flash[:notice] = t(:'flash.general.restore.failure', :human_name => 'Agent')
   end 
   redirect_to :back  
 end

 protected
 
  def build_user_and_agent
    @user  = current_account.users.build(params[:user])
    @agent = current_account.agents.new(params[nscname]) 
  end
  
  def update_agent_object
    @agent.occasional = params[:agent][:occasional]
  end
 
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
  
end
