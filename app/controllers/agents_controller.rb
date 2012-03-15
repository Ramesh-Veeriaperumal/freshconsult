class AgentsController < Admin::AdminController
  
  skip_before_filter :check_account_state, :only => :destroy
  
  before_filter :load_object, :only => [:update,:destroy,:restore,:edit]
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :check_user_permission, :only => :destroy
  before_filter :check_agent_limit, :only =>  :restore
  
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
    @user  = current_account.users.new #by Shan need to check later        
    @agent = current_account.agents.new(params[nscname]) 
    #check_agent_limit
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
  
  def create_multiple_items
    @agent_emails = params[:agents_invite_email].split(/,/)

    responseObj = {}
    if current_account.can_add_agents?(@agent_emails.length)
      @agent_emails.each do |agent_email|        
        @user  = current_account.users.new
        if @user.signup!(:user => { :email => agent_email })
          @user.create_agent
        end
      end      
      responseObj[:reached_limit] = false      
    else      
      responseObj[:reached_limit] = true      
    end   

    respond_to do |format|
      format.json { render :json => responseObj.to_json }
    end
      
  end
  
  def update
      @agent.occasional = params[:agent][:occasional]
      #check_agent_limit
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
    redirect_to :back if current_account.reached_agent_limit? and !@agent.occasional?
  end
end