# encoding: utf-8
class GroupsController < Admin::AdminController
   
  def index    
    @groups = current_account.groups.find(:all, :order =>'name')
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups.to_xml(:except=>:account_id) }
      format.json { render :json => @groups.to_json(:except=>:account_id) }
    end    
  end

  def show
    respond_to do |format|
      format.html{ redirect_to :action => 'edit' }
      @group = current_account.groups.find(params[:id])     
      format.xml  { render :xml => @group.to_xml(:except=>:account_id) }
      format.json { render :json => @group.to_json(:except=>:account_id) }
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
    
     @group = current_account.groups.find(params[:id])     
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @group }
    end
    
  end

  def create
     @group = current_account.groups.new(params[nscname])     
     agents_data = params[:group][:agent_list] 
     #for api to pass agent_id as an comma separated value/otherwise UI sends as array so each will take care.
     agents_data.split(',').each { |agent| @group.agent_groups.build(:user_id =>agent) } unless agents_data.blank?
     @group.business_calendar_id = params[:group][:business_calendar]
     if @group.save
      respond_to do |format|
        format.html { redirect_to :action => 'index' }
        format.xml { render :xml=>@group.to_xml({:except=>[:account_id]}), :status => :created }
        format.json { render :json=>@group.to_json({:except=>[:account_id]}), :status => :created }
      end
     else
      respond_to do |format|
          format.html { render :action => 'new' }
          format.json {
            result = {:errors=>@group.errors.full_messages }
            render :json => result.to_json
          }
          format.xml {
            render :xml =>@group.errors
          }
      end
     end
  end

  def update
    
     @group = current_account.groups.find(params[:id])
     @group.business_calendar_id = params[:group][:business_calendar]
     respond_to do |format|      
      if @group.update_attributes(params[nscname])
        update_agents        
        format.html { redirect_to(groups_url, :notice => 'Group was successfully updated.') }
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
        format.json { 
          result = {:errors=>@group.errors.full_messages }
          render :json => result.to_json }
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
    agents_data = params[:group][:agent_list] 
    #for api to pass agent_id as an comma separated value/otherwise UI sends as array so each will take care.
    agents_data.split(',').each {|agent_id| AgentGroup.create(:user_id =>agent_id, :group_id =>group_id ) } unless agents_data.blank?
  end
  
  

  def destroy
    
    @group = current_account.groups.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
      format.json { head :ok }
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
