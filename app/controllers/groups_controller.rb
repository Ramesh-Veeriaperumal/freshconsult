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
     @group = current_account.groups.new(params[nscname].except(:added_list, :removed_list))     
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
     filtered_params = params[nscname].reject { |k| k == "added_list" || k == "removed_list" }
     respond_to do |format|      
      if @group.update_attributes(filtered_params)
        format.html do
          update_agent_list
          redirect_to(groups_url, :notice => 'Group was successfully updated.')
        end    
        format.xml do
          update_agents
          head :ok
        end  
        format.json do
          update_agents
          head :ok
        end
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

  def toggle_roundrobin
    if current_account.features?(:disable_rr_toggle)
      current_account.features.disable_rr_toggle.destroy
    else
      current_account.features.disable_rr_toggle.create
    end
    flash[:notice] = t('group.settings_saved')
    render :action => 'index'
  end
  
protected

  def cname # Possible dead code
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end 

private
  
  def update_agent_list
    to_be_added = params[:group][:added_list].split(",")
    to_be_removed = params[:group][:removed_list].split(",")

    unless to_be_added.blank?
      valid_agents = current_account.agents.find(:all, :conditions => {:user_id => to_be_added})
      valid_agents.each { |agent| current_account.agent_groups.create(:user_id => agent.user_id, :group_id =>  params[:id]) }
    end

    AgentGroup.destroy_all(:user_id => to_be_removed, :account_id => current_account.id, :group_id => params[:id]) unless to_be_removed.blank?
  end
  
end
