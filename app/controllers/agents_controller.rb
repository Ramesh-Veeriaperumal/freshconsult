class AgentsController < ApplicationController
  def index    
    @agents = Agent.find(:all , :include => :user)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @agents }
    end
  end

  def show    
     @agent = Agent.find(params[:id])
     respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def new    
    @agent      = Agent.new    
    @agent.user = User.new    
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

  def create     
    @user  = current_account.users.new #by Shan need to check later     
    @agent = Agent.new(params[nscname]) 
    if @user.signup!(:user => params[:user])
      logger.debug "The user Id is: #{@user.id}"      
      @agent.user_id = @user.id
     
      if @agent.save
         redirect_to :action => 'index'
      else
         redirect_to :action => 'new'          
      end
      
    else      
      redirect_to :action => 'new'      
    end    
  end

  def update
    @agent = Agent.find(params[:id])
    respond_to do |format|      
      if @agent.update_attributes(params[nscname])  
          logger.debug " user id is #{@agent.user_id} and new params are #{params[:user]}"
          @user = User.find(@agent.user_id)
          logger.debug " user obj is #{@user.inspect}"
          @user.update_attributes(params[:user])
        
        #@support_plan.sla_details.update_attributes(params[:SlaDetails])
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
    @agent.destroy

    respond_to do |format|
      format.html { redirect_to(agents_url) }
      format.xml  { head :ok }
    end
end

 protected

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end

end
