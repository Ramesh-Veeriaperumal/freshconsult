class AgentsController < Admin::AdminController
    
  def index    
    @agents = current_account.agents.find(:all , :include => :user )
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @agents }
    end
  end

  def show    
     @agent = current_account.all_agents.find(params[:id])
     respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def new    
    @agent      = Agent.new       
    @agent.user = User.new
    @agent.user.avatar = Helpdesk::Attachment.new
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def edit    
     @agent = Agent.find(params[:id])    
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
        @agent.user =@user       
         render :action => :new        
    end    
  end

  def update
    @agent = Agent.find(params[:id])
    respond_to do |format|      
      if @agent.update_attributes(params[nscname])            
          @user = User.find(@agent.user_id)          
          @user.update_attributes(params[:user])        
          format.html { redirect_to(agents_url, :notice => 'Agent was successfully updated.') }
          format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @agent.errors, :status => :unprocessable_entity }
      end    
    end    
  end

  def destroy    
    @agent = Agent.find(params[:id])
    if @agent.user.update_attribute(:deleted, true)    
       @restorable = true
       flash[:notice] = render_to_string(:partial => '/agents/flash/delete_notice')      
     else
           flash[:notice] = "Agent could not be able to delete"           
     end
    redirect_to :back
end

 def restore
   
    @agent = Agent.find(params[:id])
    if @agent.user.update_attribute(:deleted, false)   
      flash[:notice] = render_to_string(:partial => '/contacts/flash/restore_notice')
    else
      flash[:notice] = "Agent could not be able to restore"
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

end
