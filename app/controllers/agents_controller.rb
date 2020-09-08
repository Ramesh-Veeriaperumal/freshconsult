# encoding: utf-8
class AgentsController < ApplicationController
  include AgentsHelper
  include UserHelperMethods
  include APIHelperMethods
  include ExportCsvUtil
  include Spam::SpamAction
  
  include Gamification::GamificationUtil
  include MemcacheKeys
  include EmailHelper
  include Freshcaller::AgentHelper
  include Freshid::CallbackMethods

  skip_before_filter :check_account_state, :only => :destroy
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:info_for_node]
  
  before_filter :load_object, only: [:show, :update, :destroy, :restore, :edit,
    :reset_password, :convert_to_contact, :reset_score, :api_key, :toggle_shortcuts]
  before_filter :sanitize_params, only: [:create, :update]

  before_filter :ssl_check, :can_assume_identity, :only => [:api_key] 
  before_filter :load_roles, :load_groups, :only => [:new, :create, :edit, :update]
  before_filter :check_demo_site, :only => [:destroy,:update,:create]
  before_filter :restrict_current_user, :only => [ :edit, :update, :destroy,
    :convert_to_contact, :reset_score, :reset_password ]
  before_filter :check_current_user, :only => [ :destroy, :convert_to_contact, :reset_password ]
  before_filter :check_agent_limit, :only =>  [:restore, :create] 
  before_filter :check_field_agent_limit, only: [:restore, :create], if: :field_service_management_enabled?
  before_filter :check_agent_limit_on_update, :validate_params, :can_edit_roles_and_permissions, :only => [:update]
  before_filter :check_role_permission, only: [:create, :update]
  before_filter :set_selected_tab
  before_filter :set_native_mobile, :only => :show
  before_filter :filter_params, :only => [:create, :update]
  before_filter :check_occasional_agent_params, :only => [:index]
  before_filter :set_filter_data, :only => [ :update,  :create]
  before_filter :set_skill_data, :only => [:new, :edit]
  before_filter :access_denied, only: :reset_password, if: :freshid_integration_enabled?

  def load_object
    @user = scoper.find(params[:id])
    @agent = @user.agent
    @scoreboard_levels = current_account.scoreboard_levels.level_up_for @agent.level
  end

  def check_demo_site
    if AppConfig['demo_site'][Rails.env] == current_account.full_domain
      error_responder(t(:'flash.not_allowed_in_demo_site'), 'forbidden')
    end
  end

  def check_edit_privilege
    if freshid_integration_enabled? && !current_account.allow_update_agent_enabled?
      return true if @agent.user_changes.key?('email') && freshid_user_details(@agent.user.email).blank?

      AgentConstants::RESTRICTED_PARAMS.any? do |key|
        return false if @agent.user_changes.key?(key)
      end
    end
    true
  end

  def search_in_freshworks
    email_changed = params[:new_email].present? && params[:new_email].casecmp(params[:old_email]) != 0
    user = email_changed ? freshid_user_details(params[:new_email]) : current_account.users.find_by_email(params[:old_email].to_s)
    user_hash = user.present? ? (email_changed ? user_info_hash(User.new, user.as_json.symbolize_keys)[:user] : user_info_hash(user)[:user]) : nil
    render :json => { :user_info => user_hash }
  end
    
  def index
    list_scoper = current_account.all_agents
    unless params[:query].blank?
      #for using query string in api calls
      @agents = list_scoper.with_conditions(convert_query_to_conditions(params[:query]))
    else
      state = params[:state] == Agent::FIELD_AGENT ? 'active' : params[:state]
      type =  fetch_agent_type(params[:state])
      @agents = list_scoper.filter(type, state, params[:letter], current_agent_order, current_agent_order_type, params[:page])
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
    respond_to do |format|
      format.html do
        @recent_unresolved_tickets = 
                            current_account.tickets.permissible(current_user).assigned_to(@user).unresolved.visible.newest(5)
      end
      format.xml  { render :xml => @agent.to_xml }
      format.json { render :json => @agent.as_json }
      format.nmobile { render json: @user.to_mob_json }
    end
  end

  def new    
    @agent      = current_account.agents.new       
    @agent.user = User.new
    @agent.user.avatar = Helpdesk::Attachment.new
    @agent.user.time_zone = current_account.time_zone
    @agent.user.language = current_portal.language
    @scoreboard_levels = current_account.scoreboard_levels.order('points ASC').to_a
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def edit  
    #@agent.signature_html ||= @agent.signature_value
    @agent_skills = gon.agent_skills = current_account.skill_based_round_robin_enabled? ? 
    @user.user_skills.preload(:skill).map do |user_skill|
      {:id => user_skill.id, :rank => user_skill.rank, 
        :skill_id => user_skill.skill_id, :name => user_skill.skill.name}
    end : []
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @agent }
    end    
  end

  def toggle_availability
    if params[:admin] || current_user.toggle_availability?
      @agent = current_account.agents.find_by_user_id(params[:id])
      @agent.toggle(:available)
      @agent.active_since = Time.now.utc
      @agent.save
      Rails.logger.debug "Round Robin ==> Account ID:: #{current_account.id}, Agent:: #{@agent.user.email}, Value:: #{params[:value]}, Time:: #{Time.zone.now} "
      Rails.logger.debug "Supervisor Round Robin ==> Account ID:: #{current_account.id}, Agent:: #{@agent.user.email}, Value:: #{params[:value]}, Time:: #{Time.zone.now} " if params[:admin] and current_user.roles.supervisor.present?
    end
    respond_to do |format|
      format.html { render :nothing => true}
      format.json  { render :json => {} }
    end    
  end
    

  def toggle_shortcuts
    @agent.update_attribute(:shortcuts_enabled, !@agent.shortcuts_enabled?)
    render :json => { :shortcuts_enabled => @agent.shortcuts_enabled? }
  end  

  def create 
    check_field_agent_roles if Account.current.field_service_management_enabled?
    @user  = current_account.users.new #by Shan need to check later    
    group_ids = params[nscname].delete(:group_ids)
    @agent = current_account.agents.new(params[nscname]) 

    #for live chat sync
    # @agent.agent_role_ids = params[:user][:role_ids]
    #check_agent_limit
    if @user.signup!({:user => params[:user]}, nil, !freshid_integration_enabled?)       
      @agent.user_id = @user.id
      @agent.scoreboard_level_id = params[:agent][:scoreboard_level_id]
      @agent.freshcaller_enabled = (params[:freshcaller_agent].try(:to_bool) || false)
      @agent.freshchat_enabled = params[:freshchat_agent].try(:to_bool) if params[:freshchat_agent].present?
      @agent.build_agent_groups_attributes(group_ids)
      if @agent.save
        flash[:notice] = t(:'flash.agents.create.success', :email => @user.email)
        freshcaller_alerts
        redirect_to :action => 'index'
      else
        set_skill_data
        Account.current.users.where(id: @user.id).first.try(:destroy)
        @user  = current_account.users.new
        @agent = current_account.agents.new
        @agent.user = User.new
        @agent.user.avatar = Helpdesk::Attachment.new
        @agent.user.time_zone = current_account.time_zone
        @agent.user.language = current_portal.language
        render :action => :new
      end
    else  
        check_email_exist
        @agent.user =@user
        @scoreboard_levels = current_account.scoreboard_levels.order('points ASC').to_a
        set_skill_data
        render :action => :new
    end
  end

  def check_field_agent_roles
    if params[:agent][:agent_type] == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
      params[:user][:role_ids] = [Account.current.roles.find_by_name('Field technician').id]
    end
  end
  
  def create_multiple_items
    @agent_emails = params[:agents_invite_email].reject {|e| e.empty?}
    @responseObj = {}
    if !account_whitelisted? && current_account.subscription.agent_limit.nil? && (@agent_emails.length > 25)
      @responseObj[:reached_limit] = :blocked
    elsif current_account.can_add_agents?(@agent_emails.length)
      @existing_users = [];
      @new_users = [];
      @agent_emails.each do |agent_email|
        next if agent_email.blank?        
        @user  = current_account.users.new
        if @user.signup!({:user => { 
            :email => agent_email,
            :helpdesk_agent => true,
            :role_ids => [current_account.roles.find_by_name("Agent").id]
            }}, nil, !freshid_integration_enabled?)
          @user.create_agent
          @new_users << @user
        # Has no use in getting started
        # else
        #   check_email_exist
        #   @existing_users << @existing_user 
        end        
      end      
            
      @responseObj[:reached_limit] = :false
    else      
      @responseObj[:reached_limit] = :true
    end              
  end

  def sanitize_params
    params['agent']['occasional'] = (params['agent']['agent_type'] == 'occasional')
    params['agent']['agent_type'] = params['agent']['agent_type'] == 'field_agent' ? AgentType.agent_type_id(Agent::FIELD_AGENT) : AgentType.agent_type_id(Agent::SUPPORT_AGENT)
  end

  def update
    @agent.occasional = params[:agent][:occasional] || false
    #check_agent_limit
    @agent.scoreboard_level_id = params[:agent][:scoreboard_level_id] if gamification_feature?(current_account)
    @agent.freshcaller_enabled = (params[:freshcaller_agent].try(:to_bool) || false)
    @agent.freshchat_enabled = params[:freshchat_agent].try(:to_bool) unless params[:agent][:freshchat_agent].nil?
    # @user = @agent.user
    # @agent.user.attributes = params[:user]
    #for live chat sync
    # @agent.agent_role_ids = params[:user][:role_ids]
    params[:user].each do |k, v|
      @agent.user.safe_send("#{k}=", v)
    end
    @agent.user_changes = @agent.user.agent.user_changes || {}
    @agent.user_changes.merge!(@agent.user.changes)
    return render json: { success: false, errors: t(:'flash.agents.edit.not_allowed_to_edit_inaccessible_fields') }, status: 403 unless check_edit_privilege

    group_ids = params[nscname].delete(:group_ids)
    @agent.build_agent_groups_attributes(group_ids)
    if @agent.update_attributes(params[nscname])
      begin
        if @user.role_ids.include?(current_account.roles.find_by_name("Account Administrator").id)
          call_location = "Agent Update"
          SpamDetection::SignupRestrictedDomainValidation.perform_async({:account_id=>current_account.id, :email=>@user.email, :call_location=>call_location})
        end
      rescue Exception => e
        Rails.logger.info "SignupRestrictedDomainValidation failed. #{current_account.id}, #{e.message}, #{e.backtrace}"
      end
      respond_to do |format|
        format.html do
          flash[:notice] = t(:'flash.general.update.success', :human_name => 'Agent')
          freshcaller_alerts
          if current_account.falcon_ui_enabled?(current_user)
            render :nothing => true
          else
            redirect_to :action => 'index'
          end
        end
        format.json {head :ok}
        format.xml {head :ok } 
      end  
    else
      check_email_exist @agent.user
      @agent.user = @user       
      errors = @agent.user.errors.present? ? @agent.user.errors : 
                @agent.errors
      errors =  errors.messages.has_key?(:"user.base") ? errors.values : errors.full_messages
      result = { errors: errors }
      respond_to do |format|
        format.html {
          flash[:error] = t(:"flash.agents.edit.#{@agent.errors.messages[:agent_type]}") if @agent.errors.messages[:agent_type].present?
          set_skill_data
          if current_account.falcon_ui_enabled?(current_user)
            render :nothing => true
          else
            redirect_to :action => 'edit'
          end
         }
        format.json { render :json => result.to_json, :status => :bad_request }
        format.xml {render :xml => result.to_xml, :status => :bad_request } 
      end
    end
  end

  def convert_to_contact
    if @user.make_customer
      # current_account subscription state changing from "active" to "Active" after
      # user.make_customer, so using downcase to check active customers
      if current_account.subscription.state.casecmp("active").zero?
        flash[:notice] = t(:'flash.agents.to_contact_active', subscription_link: '/subscription').html_safe
      else
        flash[:notice] = t(:'flash.agents.to_contact')
      end
      @user.toggle_ui_preference if @user.is_falcon_pref?
      redirection_url(@user)
    else
      flash[:notice] = t(:'flash.agents.to_contact_failed')
      redirect_to :back and return
    end
  end
  
  def destroy    
    if @user.update_attributes(deleted: true)
      @user.email_notification_agents.destroy_all
      @restorable = true
      flash[:notice] = render_to_string(partial: '/agents/flash/delete_notice')
    else
      flash[:notice] = t(:'flash.general.destroy.failure', human_name: 'Agent')
    end
    redirect_to :back
  end

 def restore  # Possible dead code(restore)
   if @user.update_attributes(:deleted => false,
       :role_ids => [current_account.roles.find_by_name("Agent").id]
    )   
    flash[:notice] = render_to_string(:partial => '/agents/flash/restore_notice')
   else
     logger.info "Errors in agent restore :: #{@user.errors.full_messages}"
     flash[:notice] = t(:'flash.general.restore.failure', human_name: 'Agent')
   end 
   redirect_to :back  
 end

  def reset_password
    if @user.active?
      @user.reset_agent_password(current_portal)
      flash[:notice] = t(:'flash.password_resets.email.reset', requester: h(@user.email))
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
    api_key = { user_id: @user.id, api_key: @user.single_access_token }
     respond_to do |format|
          format.html{render_404}
          format.any(:xml, :json) { render request.format.to_sym => api_key }
      end
  end 

  def configure_export
    @csv_headers = Agent.allowed_export_fields
    render :layout => false
  end

  def export_csv
    if valid_export_params?
      ExportAgents.perform_async({:csv_hash => params[:export_fields], 
                                            :user => current_user.id, 
                                            :portal_url => fetch_portal_url})
      flash[:notice] = t('agent.export_successfull')
    else
      flash[:notice] = t('agent.invalid_export_params')
    end
    redirect_to :back
  end

  def reset_score
    GamificationReset.perform_async({"agent_id" => @agent.id })
    flash[:notice] = I18n.t('gamification.score_reset_successfull')
    redirect_to agent_path(@user)
  end

  def export_skill_csv
    csv_string = Export::AgentDetail.new({:csv_hash => Agent::SKILL_EXPORT_FIELDS,
                        :send_mail => false, :portal_url => fetch_portal_url}).perform
    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present',
            :disposition => "attachment; filename=agent_skill_export.csv"
  end

 protected
 
  def scoper
    current_account.all_technicians
  end

  def cname # Possible dead code(cname)
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def check_email_exist object=@user
    if Array.wrap(object.errors.messages[:"primary_email.email"]).include? "has already been taken"
      @existing_user = current_account.user_emails.user_for_email(params[:user][:email])
    end
  end
  
  def check_agent_limit
    if current_account.reached_agent_limit?
      if (@agent && @agent.support_agent? && !@agent.occasional?) || (params[:agent] && params[:agent][:occasional] != true && params[:agent][:agent_type] == AgentType.agent_type_id(Agent::SUPPORT_AGENT))
        flash[:notice] = t('maximum_agents_msg')
        redirect_to :back 
      end
    end
  end

  def check_field_agent_limit
    if current_account.reached_field_agent_limit?
      if (@agent && @agent.field_agent?) || (params[:agent] && params[:agent][:agent_type] == AgentType.agent_type_id(Agent::FIELD_AGENT))
        flash[:notice] = t('maximum_field_agents_msg')
        redirect_to :back
      end
    end
  end
  
  def check_agent_limit_on_update
    if current_account.reached_agent_limit? && @agent.occasional? && current_account.occasional_agent_enabled? && params[:agent]
      params[:agent][:occasional] = true 
    end
  end

  def set_selected_tab
    @selected_tab = :admin
  end

  def load_roles
    @roles = current_account.roles.all
  end
  
  def load_groups
    @groups = current_account.groups_from_cache
  end

  def restrict_current_user
    unless can_edit?(@agent)
      error_responder(t(:'flash.agents.edit.not_allowed'), 'forbidden')
    end    
  end
    
  def check_current_user
    if current_user == @user
      flash[:notice] = t(:'flash.agents.edit.not_allowed')
      redirect_to :back  
    end
  end
  
  def redirection_url(user) # Moved out to overwrite in Freshservice
    redirect_to contact_path(user)
  end
 
private

  def set_filter_data
    user_skills = params[:user][:user_skills_attributes] || []
    params[:user][:user_skills_attributes] = user_skills.is_a?(Array) ?
    user_skills : ActiveSupport::JSON.decode(user_skills)
  end

  def set_skill_data
    @skills = gon.allSkills = current_account.skill_based_round_robin_enabled? ?
     current_account.skills_trimmed_version_from_cache.map { |skill| 
      {:skill_id=>skill.id, :name=>skill.name} 
     } : []
    @manage_skills = @skills.present? && current_user.privilege?(:manage_skills)
  end

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
    unless is_allowed_to_assume?(@user)
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
    role_ids = current_account.roles.where(id: role_ids).pluck(:id) if role_ids.present?
    if role_ids.blank?
      params[:user].delete(:role_ids)
    else
      params[:user][:role_ids] = role_ids
    end
  end
  
  def validate_groups
    group_ids = params[:agent][:group_ids]
    if group_ids.nil? or (group_ids.kind_of?(Array) and group_ids.all? &:blank?)
      params[:agent][:group_ids] = []
    else
      params[:agent][:group_ids] = current_account.groups.where(:id => group_ids).map(&:id)
    end
  end

  def validate_ticket_permission
    #validating permissions
    if !current_account.agent_scope_enabled? || Agent::PERMISSION_TOKENS_BY_KEY[params[:agent][:ticket_permission].to_i].blank?
      params[:agent].delete(:ticket_permission)
    end
  end

  def format_api_params
    #if not specified in API request, updated as null
    params[:agent][:scoreboard_level_id] ||= @agent.scoreboard_level_id
    #conforming API params to html params
    params[:user] = params[:user] || params[:agent][:user] || {}
    params[:agent].delete(:user)
  end
 
  def filter_params
    if params[:action].eql?('update')
      params[:agent].except!(:user_id, :available, :active_since) # should we expose "available" ?
      params[:user].except!(:helpdesk_agent, :deleted, :active)
      validate_phone_field_params @user
    end
    # remove params[:agent][:occasional] if occasional_agent feature is not enabled
    params[:agent].except!(:occasional) unless current_account.occasional_agent_enabled?
  end

  def validate_params
    validate_scoreboard_level
    validate_ticket_permission
    format_api_params
    validate_roles
    validate_groups
  end

  def can_edit_roles_and_permissions # Should be checked after validate_params as params hash is unified in validate_params
    error_responder(t('agent.cannot_edit_roles'), 'forbidden') if (params[:agent][:ticket_permission] || params[:user][:role_ids]) && (current_user == @user)
  end

  def check_role_permission
    return if current_user.privilege?(:manage_account)

    roles = current_account.roles.where(id: params[:user][:role_ids])
    error_responder(t('agent.role_assign_error'), 'forbidden') if roles.any? { |role| role.privilege?(:manage_account) }
  end

  def error_responder error_message, status
    error = {:errors => {:message=> error_message } }
    respond_to do |format|
        format.html { flash[:notice] = error_message
                              redirect_to :back }
        format.any(:xml, :json) {render request.format.to_sym => error, :status => status.to_sym}
    end
  end

  def valid_export_params?
    params[:export_fields].values.all? { |param| Agent::EXPORT_FIELD_VALUES.include? param }
  end

  def check_occasional_agent_params
    redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) if params[:state].to_s == "occasional" and !current_account.occasional_agent_enabled?
  end

  def fetch_portal_url
    main_portal? ? current_account.host : current_portal.portal_url
  end

  def fetch_agent_type(state)
    if state == Agent::FIELD_AGENT
      AgentType.agent_type_id(Agent::FIELD_AGENT)
    elsif state == Agent::DELETED_AGENT
      nil
    else
      AgentType.agent_type_id(Agent::SUPPORT_AGENT)
    end
  end

  def freshid_user_details(email)
    current_account.freshid_org_v2_enabled? ? Freshid::V2::Models::User.find_by_email(email.to_s) : Freshid::User.find_by_email(email.to_s)
  end
end

