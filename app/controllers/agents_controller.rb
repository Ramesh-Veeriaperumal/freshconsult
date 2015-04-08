# encoding: utf-8
class AgentsController < ApplicationController
  include AgentsHelper
  helper AgentsHelper
  include APIHelperMethods
  
  include Gamification::GamificationUtil
  include MemcacheKeys

  skip_before_filter :check_account_state, :only => :destroy
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:info_for_node]
  
  before_filter :load_object, :only => [:update, :destroy, :restore, :edit, :reset_password, 
    :convert_to_contact, :api_key] 
  before_filter :ssl_check, :can_assume_identity, :only => [:api_key] 
  before_filter :load_roles, :only => [:new, :create, :edit, :update]
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :restrict_current_user, :only => [ :edit, :update, :destroy,
    :convert_to_contact, :reset_password ]
  before_filter :check_current_user, :only => [ :destroy, :convert_to_contact, :reset_password ]
  before_filter :check_agent_limit, :only =>  [:restore, :create] 
  before_filter :check_agent_limit_on_update, :validate_params, :can_edit_roles_and_permissions, :only => [:update]
  before_filter :set_selected_tab
  before_filter :set_native_mobile, :only => :show
  
  def load_object
    @agent = scoper.find(params[:id])
    @scoreboard_levels = current_account.scoreboard_levels.level_up_for @agent.level
  end

  def check_demo_site
    if AppConfig['demo_site'][Rails.env] == current_account.full_domain
      error_responder(t(:'flash.not_allowed_in_demo_site'), 'forbidden')
    end
  end
    
  def index    
    unless params[:query].blank?
      #for using query string in api calls
      @agents = scoper.with_conditions(convert_query_to_conditions(params[:query])) 
    else
      @agents = scoper.filter(params[:state],params[:letter], current_agent_order, current_agent_order_type, params[:page])
    end
    respond_to do |format|
      format.html #index.html.erb
      format.js do
        render 'index', :formats => [:rjs] 
      end
      format.xml  { render :xml => @agents.to_xml }
      format.json  { render :json => @agents.to_json }
    end
  end

  def show    
    @agent = current_account.all_agents.find(params[:id])
    respond_to do |format|
      format.html do
        @user = @agent.user
        @recent_unresolved_tickets = 
                            current_account.tickets.assigned_to(@user).unresolved.visible.newest(5)
      end
      format.xml  { render :xml => @agent.to_xml }
      format.json { render :json => @agent.as_json }
      format.nmobile { render :json => @agent.user.to_mob_json }
    end
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
    @agent.toggle(:available)
    @agent.active_since = Time.now.utc
    @agent.save
    Rails.logger.debug "Round Robin ==> Account ID:: #{current_account.id}, Agent:: #{@agent.user.email}, Value:: #{params[:value]}, Time:: #{Time.zone.now} "
    respond_to do |format|
      format.html { render :nothing => true}
      format.json  { render :json => {} }
    end    
  end
    

  def toggle_shortcuts
    @agent = scoper.find(params[:id])
    @agent.update_attribute(:shortcuts_enabled, !@agent.shortcuts_enabled?)
    render :json => { :shortcuts_enabled => @agent.shortcuts_enabled? }
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
          respond_to do |format|
            format.html { flash[:notice] = t(:'flash.general.update.success', :human_name => 'Agent')
                          redirect_to :action => 'index'
                        }        
            format.json {head :ok}
            format.xml {head :ok } 
          end  
        else
          check_email_exist
          @agent.user =@user       
          result = {:errors=>@user.errors.full_messages }    
          respond_to do |format|
            format.html { render :action => :edit }
            format.json { render :json => result.to_json, :status => :bad_request }
            format.xml {render :xml => result.to_xml, :status => :bad_request } 
          end    
       end
    else
      @agent.user = @user       
      result = {:errors=>@agent.errors.full_messages }    
      respond_to do |format|
        format.html { render :action => :edit }
        format.json { render :json => result.to_json, :status => :bad_request }
        format.xml {render :xml => result.to_xml, :status => :bad_request } 
      end    
    end 
  end

  def convert_to_contact
      user = @agent.user
      if user.make_customer
        flash[:notice] = t(:'flash.agents.to_contact')
        redirection_url(user)
      else
        flash[:notice] = t(:'flash.agents.to_contact_failed')
        redirect_to :back and return
      end
  end
  
  def destroy    
    if @agent.user.update_attributes(:deleted => true)    
       @agent.user.email_notification_agents.destroy_all
       @restorable = true
       flash[:notice] = render_to_string(:partial => '/agents/flash/delete_notice')      
     else
       flash[:notice] = t(:'flash.general.destroy.failure', :human_name => 'Agent')
     end
    redirect_to :back
  end

 def restore  # Possible dead code(restore)
   @agent = current_account.all_agents.find(params[:id])
   if @agent.user.update_attributes(:deleted => false,
       :role_ids => [current_account.roles.find_by_name("Agent").id]
    )   
    flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
   else
    logger.info "Errors in agent restore :: #{@agent.user.errors.full_messages}" 
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
    key = %{#{NodeConfig["rest_secret_key"]}#{current_account.id}#{params[:user_id]}}
    hash = Digest::MD5.hexdigest(key)
      
    if hash == params[:hash]
      agent = current_account.agents.find_by_user_id(params[:user_id])
      agent_detail = { :ticket_permission => agent.ticket_permission, 
                       :group_ids => agent.agent_groups.map(&:group_id) }
       render :json => agent_detail
    else 
      render :json => {
        :error => "Access denied!"
      }
    end
  end

  def api_key
    api_key = {:user_id => @agent.user_id, :api_key => @agent.user.single_access_token}
     respond_to do |format|
          format.html{render_404}
          format.any(:xml, :json) { render request.format.to_sym => api_key }
      end
  end 

 protected
 
  def scoper
     current_account.all_agents
  end

  def cname # Possible dead code(cname)
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def check_email_exist
    if(@user.errors.messages[:"primary_email.email"].include? "has already been taken")
      @existing_user = current_account.user_emails.user_for_email(params[:user][:email])
    end
  end
  
  def check_agent_limit
    if current_account.reached_agent_limit? 
      if (@agent && !@agent.occasional?) || (params[:agent] && params[:agent][:occasional] != "true")
        flash[:notice] = t('maximum_agents_msg')
        redirect_to :back 
      end
    end
  end

  def check_agent_limit_on_update
    if current_account.reached_agent_limit? && @agent.occasional? && params[:agent] 
      params[:agent][:occasional] = true 
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
      error_responder(t(:'flash.agents.edit.not_allowed'), 'forbidden')
    end    
  end
    
  def check_current_user
    if(current_user == @agent.user)
      flash[:notice] = t(:'flash.agents.edit.not_allowed')
      redirect_to :back  
    end
  end
  
  def redirection_url(user) # Moved out to overwrite in Freshservice
    redirect_to contact_path(user)
  end
 
private

  def ssl_check
    unless request.ssl?
      error = {:errors => {:message=> t('non_ssl_request')} }
      respond_to do |format|
          format.html {render_404}
          format.any(:xml, :json) { render request.format.to_sym => error, :status => :forbidden }
      end
    end
  end

  def can_assume_identity 
    unless is_allowed_to_assume?(@agent.user)
      error = {:errors => {:message=> t('flash.general.access_denied')} }
        respond_to do |format|
            format.html{render_404}
            format.any(:xml, :json) { render request.format.to_sym => error, :status => :forbidden }
        end 
    end  
  end

  def validate_scoreboard_level
    #validating Score board level ids
    params[:agent].delete(:scoreboard_level_id) unless @scoreboard_levels.map(&:id).include?(params[:agent][:scoreboard_level_id].to_i)
  end

  def validate_roles  
    #Validating role ids. API - CSV(To maintain consistency across all APIs), HTML - array
    role_ids = params[:user][:role_ids] #[],[1,2],"","1,2,3" --> [],[1,2,3],[],[1,2,3]
    role_ids = params[:user][:role_ids].split(',').map{|x| x.to_i} if role_ids.is_a? String
    role_ids = current_account.roles.find_all_by_id(role_ids, :select => "id").map(&:id) unless role_ids.blank?
    if role_ids.blank?
      params[:user].delete(:role_ids)
    else
      params[:user][:role_ids] = role_ids
    end
  end

  def validate_ticket_permission
    #validating permissions
     params[:agent].delete(:ticket_permission) if Agent::PERMISSION_TOKENS_BY_KEY[params[:agent][:ticket_permission].to_i].blank?
  end

  def format_api_params
    #if not specified in API request, updated as null
    params[:agent][:occasional] ||= @agent.occasional
    params[:agent][:scoreboard_level_id] ||= @agent.scoreboard_level_id
    #conforming API params to html params
    params[:user] = params[:user] || params[:agent][:user] || {}
    params[:agent].delete(:user)
  end
 
  def clean_params
    params[:agent].except!(:user_id, :available, :active_since) # should we expose "available" ?
    params[:user].except!(:helpdesk_agent, :deleted, :active)
  end

  def validate_params
    validate_scoreboard_level
    validate_ticket_permission
    format_api_params
    clean_params
    validate_roles
  end

  def can_edit_roles_and_permissions # Should be checked after validate_params as params hash is unified in validate_params
    if(params[:agent][:ticket_permission]  || params[:user][:role_ids]) && (current_user == @agent.user)
     error_responder(t('agent.cannot_edit_roles'), 'forbidden')
    end
  end

  def error_responder error_message, status
    error = {:errors => {:message=> error_message } }
    respond_to do |format|
        format.html { flash[:notice] = error_message
                              redirect_to :back }
        format.any(:xml, :json) {render request.format.to_sym => error, :status => status.to_sym}
    end
  end

end