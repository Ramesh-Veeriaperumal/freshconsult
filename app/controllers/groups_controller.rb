class GroupsController < Admin::AdminController
   
  def index
    
      @groups = current_account.groups.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
    
  end

  def show
     @group = Group.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  def new
    
    @group = current_account.groups.new    
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
    
    
  end

  def edit
    
     @group = Group.find(params[:id])     
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @group }
    end
    
  end

  def create
     @group = current_account.groups.new(params[nscname])     
     agents_data = params[:AgentGroups][:agent_list]     
     @agents = ActiveSupport::JSON.decode(agents_data)         
     @agents.each_key { |agent| @group.agent_groups.build(:user_id =>agent) }     
     if @group.save
        redirect_to :action => 'index'
     else
        render :action => 'new'
     end
  end

  def update
    
     @group = Group.find(params[:id])
     respond_to do |format|      
      if @group.update_attributes(params[nscname])
        update_agents        
        format.html { redirect_to(groups_url, :notice => 'Group was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => Group.errors, :status => :unprocessable_entity }
      end
    end
    
  end
  
  def update_agents 
    
    @agents = AgentGroup.find(:all, :conditions=>{:group_id => params[:id]})
    unless @agents.nil?
      @agents.each do |agent|
        agent.destroy
      end    
    end
    
    add_agents params[:id]    
  end
  
  def add_agents group_id
    
    agents_data = params[:AgentGroups][:agent_list]     
    @agents = ActiveSupport::JSON.decode(agents_data)
    @agents.each_key { |agent| AgentGroup.create(:user_id =>agent, :group_id =>group_id )  }
  end
  
  

  def destroy
    
      @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
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
