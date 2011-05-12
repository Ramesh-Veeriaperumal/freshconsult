class AgentsController < Admin::AdminController
  
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  
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
    @recent_unresolved_tickets = current_account.tickets.assigned_to(@user).unresolved.newest(5)
    #redirect_to :action => 'edit'
  end

  def new    
    @agent      = Agent.new       
    @agent.user = User.new
    @agent.user.avatar = Helpdesk::Attachment.new
    @agent.user.time_zone = current_account.time_zone
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def edit    
     @agent = current_account.all_agents.find(params[:id])    
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @agent }
    end    
  end
  
  def delete_avatar
    @user = User.find(params[:id])
    @user.avatar.destroy
    render :text => "success"
  end

  def create   
    
    @user  = current_account.users.new #by Shan need to check later        
    @agent = Agent.new(params[nscname]) 
    
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
    @agent = Agent.find(params[:id])
   
      if @agent.update_attributes(params[nscname])            
          @user = User.find(@agent.user_id)          
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
    @agent = Agent.find(params[:id])
    if @agent.user.update_attribute(:deleted, true)    
       @restorable = true
       flash[:notice] = render_to_string(:partial => '/agents/flash/delete_notice')      
     else
           flash[:notice] = "Agent could not be deleted"           
     end
    redirect_to :back
end

 def restore
   
    @agent = Agent.find(params[:id])
    if @agent.user.update_attribute(:deleted, false)   
      flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
    else
      flash[:notice] = "Agent could not be restored"
    end
    
    redirect_to :back
   
 end

 protected

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
