# encoding: utf-8
class AgentsController < ApplicationController
  include AgentsHelper
  helper AgentsHelper
  include APIHelperMethods
  
  include Gamification::GamificationUtil
  include MemcacheKeys

  skip_before_filter :check_account_state, :only => :destroy
  skip_before_filter :check_privilege, :only => [:info_for_node]
  
  before_filter :load_object, :only => [:update, :destroy, :restore, :edit, :reset_password, 
    :convert_to_contact ]
  before_filter :load_roles, :only => [:new, :create, :edit, :update]
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :restrict_current_user, :only => [ :edit, :update, :destroy,
    :convert_to_contact, :reset_password ]
  before_filter :check_current_user, :only => [ :destroy, :convert_to_contact, :reset_password ]
  before_filter :check_agent_limit, :only =>  :restore
  before_filter :set_selected_tab
  
  def load_object
    @agent = scoper.find(params[:id])
    @scoreboard_levels = current_account.scoreboard_levels.level_up_for @agent.level
  end

  def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = t(:'flash.not_allowed_in_demo_site')
      redirect_to :back
    end
  end
    
  def index    
    unless params[:query].blank?
      #for using query string in api calls
      @agents = scoper.with_conditions(convert_query_to_conditions(params[:query])).filter 
    else
      @agents = scoper.filter(params[:state], current_agent_order, current_agent_order_type, params[:page])
    end
    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @agents.to_xml({:except=>[:account_id,:google_viewer_id],:include=>:user}) }
      format.json  { render :json => @agents.to_json({:except=>[:account_id,:google_viewer_id] ,:include=>{:user=>{:only=>[:id,:name,:email,:created_at,:updated_at,:job_title,
                    :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                    :helpdesk_agent,:fb_profile_id,:external_id,:language,:address] }}}) } #Adding the attributes from user as that is what is needed
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
    @scoreboard_levels = current_account.scoreboard_levels.find(:all, :order => "points ASC")
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def edit    
    #@agent.signature_html ||= @agent.signature_value
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def toggle_availability
    @agent = current_account.agents.find_by_user_id(params[:id])
    @agent.available = params[:value]
    @agent.save
    render :nothing => true
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
      @agent.scoreboard_level_id = params[:agent][:scoreboard_level_id]
      if @agent.save
         flash[:notice] = t(:'flash.agents.create.success', :email => @user.email)
         redirect_to :action => 'index'
      else      
        render :action => :new         
      end
    else       
        check_email_exist
        @agent.user =@user
        @scoreboard_levels = current_account.scoreboard_levels.find(:all, :order => "points ASC")       
        render :action => :new        
    end    
  end
  
  def create_multiple_items
    @agent_emails = params[:agents_invite_email]

    @responseObj = {}
    if current_account.can_add_agents?(@agent_emails.length)
      @existing_users = [];
      @new_users = [];
      @agent_emails.each do |agent_email|        
        @user  = current_account.users.new
        if @user.signup!(:user => { 
            :email => agent_email,
            :helpdesk_agent => true,
            :role_ids => [current_account.roles.find_by_name("Agent").id]
        })
          @user.create_agent
          @new_users << @user
        else
          check_email_exist
          @existing_users << @existing_user
        end
        
      end      
            
      @responseObj[:reached_limit] = false
    else      
      @responseObj[:reached_limit] = true
    end              
  end
  
  def update
    @agent.occasional = params[:agent][:occasional]
    #check_agent_limit
    @agent.scoreboard_level_id = params[:agent][:scoreboard_level_id] if gamification_feature?(current_account)
    @user = current_account.all_users.find(@agent.user_id)
    
    if @agent.update_attributes(params[nscname])            
        if @user.update_attributes(params[:user])
          flash[:notice] = t(:'flash.general.update.success', :human_name => 'Agent')
          redirect_to :action => 'index'
        else
           check_email_exist
           @agent.user =@user       
           render :action => :edit 
       end
    else
      @agent.user = @user       
      render :action => :edit
    end    
  end

  def convert_to_contact
      user = @agent.user
      user.make_customer
      flash[:notice] = t(:'flash.agents.to_contact')
      redirect_to contact_path(user)
  end
  
  def destroy    
    if @agent.user.update_attributes(:deleted => true)    
       @restorable = true
       flash[:notice] = render_to_string(:partial => '/agents/flash/delete_notice')      
     else
       flash[:notice] = t(:'flash.general.destroy.failure', :human_name => 'Agent')
     end
    redirect_to :back
  end

 def restore  
   @agent = current_account.all_agents.find(params[:id])
   if @agent.user.update_attributes(:deleted => false,
       :role_ids => [current_account.roles.find_by_name("Agent").id]
    )   
    flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
   else
    flash[:notice] = t(:'flash.general.restore.failure', :human_name => 'Agent')
   end 
   redirect_to :back  
 end

  def reset_password
    if @agent.user.active?
      @agent.user.reset_agent_password(current_portal)
      flash[:notice] = t(:'flash.password_resets.email.reset', :requester => h(@agent.user.email))      
      redirect_to :back
    end
  end

  def info_for_node
    key = %{#{NodeConfig["secret_key"]}#{current_account.id}#{params[:user_id]}}
    hash = Digest::SHA512.hexdigest(key)
    
    if hash == params[:hash]
      agent = current_account.agents.find_by_user_id(params[:user_id])
      agent_detail = { :ticket_permission => agent.ticket_permission, 
                       :group_ids => agent.agent_groups.map(&:group_id) }
      key = AUTO_REFRESH_AGENT_DETAILS % { :account_id => current_account.id, 
                                           :user_id => params[:user_id] }
      MemcacheKeys.cache(key, agent_detail.to_json, 86400*15, true)
      render :json => agent_detail
    else 
      render :nothing => true
    end
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
    if current_account.reached_agent_limit? and !@agent.occasional?
      flash[:notice] = t('maximum_agents_msg')
      redirect_to :back 
    end
  end

  def set_selected_tab
    @selected_tab = :admin
  end

  def load_roles
    @roles = current_account.roles.all
  end
  
  def restrict_current_user
    unless can_edit?(@agent)
      flash[:notice] = t(:'flash.agents.edit.not_allowed')
      redirect_to :back
    end    
  end
    
  def check_current_user
    if(current_user == @agent.user)
      flash[:notice] = t(:'flash.agents.edit.not_allowed')
      redirect_to :back  
    end
  end
  
end