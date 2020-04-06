class ProfilesController < ApplicationController

  include ModelControllerMethods  
  include ProfilesHelper
  include UserHelperMethods  
  include FalconHelperMethods
  include Integrations::ProfileHelper

  USER_UPDATABLE_ATTRIBUTES =  [:name, :job_title, :phone, :mobile, :time_zone, :language, :avatar_attributes => [:content, :id, :_destroy]].freeze
  USER_UPDATABLE_ATTRIBUTES_FRESHID = [ :time_zone, :language, :avatar_attributes => [:content, :id, :_destroy]].freeze

   before_filter :require_user 
   before_filter :load_profile, :only => [:edit, :change_password]
   before_filter :set_profile, :filter_params, :only => [:update]
   before_filter :load_password_policy, :check_apps ,:only => :edit
   before_filter :set_native_mobile, :only => [:update]
   before_filter :only => :change_password do |c|
     access_denied if freshid_agent?(current_user.email)
   end

   skip_before_filter :check_privilege, :except => [:edit, :update, :reset_api_key]

  def edit       
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @profile }
    end      
  end

  def create
  end

  def update 
    update_agent
  end
  
  def reset_api_key
    begin
      current_user.reset_single_access_token
      saved = current_user.save!
      @profile = current_user.customer? ? current_user : current_user.agent    
      Rails.logger.debug "single access token reset status #{saved}"
      flash[:notice] = t("flash.profile.api_key.reset_success")
    rescue => e
      Rails.logger.error "Something went wrong while resetting the api key ( #{e.inspect})"
      flash[:error] = t("flash.profile.api_key.reset_failure")
    end
    redirect_to edit_profile_url(current_user.id)
  end

  def change_password    
    @check_session = current_account.user_sessions.new(:email => current_user.email, :password => params[:user][:current_password], :remember_me => false)
    if @check_session.save 
      if reset_password
        flash[:notice] = t(:'flash.profile.change_password.success')
        @check_session.destroy
        current_user_session.destroy
        @password_failed = false
        if current_account.falcon_ui_enabled?(current_user) and current_user.agent?
          render :partial => '/profiles/change_password.rjs'
        else
          redirect_to new_user_session_url
        end
      else
        change_password_fail 
      end
    else     
      flash[:error] = t(:'flash.profile.change_password.failure')
      change_password_fail
    end      
  end

  def reset_password
    return false if params[:user][:password] != params[:user][:password_confirmation] || params[:user][:password].blank?

    @user = current_user
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    @user.active = true #by Shan need to revisit..
    result = @user.save
    @user.reset_perishable_token! if result
    flash[:error] = @user.errors.full_messages.join("<br/>").html_safe if @user.errors.any?
    result
  end
  
  def destroy
  end

  def notification_read
    current_user.agent.update_attribute(:notification_timestamp, Time.new.utc)
    head 200
  end

def on_boarding_complete
    current_user.agent.update_attribute(:onboarding_completed, false)
    head 200
end

private

  def load_profile
    @profile = current_user.customer? ? current_user : current_user.agent    
  end

  def set_profile
    @profile = current_user.agent  
  end

  def load_password_policy
    @password_policy = current_user.agent? ? current_account.agent_password_policy : current_account.contact_password_policy 
  end

  def update_agent
    respond_to do |format|
      params[:user].each do |k, v|
        @profile.user.safe_send("#{k}=", v)
      end
      @profile.user_changes = @profile.user.changes
      if @profile.update_attributes(params[:agent])
        format.html { 
          flash[:notice] = 'Your profile has been updated successfully.'
          if request.xhr? || current_account.falcon_ui_enabled?(current_user)
            render :nothing => true
          else
            redirect_to(edit_profile_url)
          end
        }
        format.xml  { head :ok }
        format.nmobile {render :json => { :success => true }}
      else
        format.html { 
          if request.xhr? || current_account.falcon_ui_enabled?(current_user)
            head :unprocessable_entity
          else
            redirect_to(edit_profile_url, flash: { error: activerecord_error_list(@profile.errors) })
          end
        }
        format.xml  { render :xml => @profile.errors, :status => :unprocessable_entity }
        format.nmobile {render :json => { :success => false }}
      end    
    end    
  end

  def change_password_fail
    @password_failed = true

    if current_user.customer?
      redirect_to edit_support_profile_path
    elsif current_account.falcon_ui_enabled?(current_user)
      render partial: '/profiles/change_password.rjs'
    else
      redirect_to edit_profile_path # redirect_to used to fix breadcrums issue in Freshservice
    end
  end

  def check_apps
    owners = ChannelIntegrations::Constants::OWNERS_LIST
    redis_info = ChannelIntegrations::Constants::INTEGRATIONS_REDIS_INFO

    @installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:slack_v2]).first
    if @installed_app and @installed_app.configs_allow_slash_command
      @authorized = Integrations::UserCredential.where(:account_id => current_account.id, :installed_application_id => @installed_app.id,:user_id => current_user.id).first
      redirect_url =  "#{AppConfig['integrations_url'][Rails.env]}/auth/slack?origin=id%3D#{current_account.id}%26portal_id%3D#{current_portal.id}%26user_id%3D#{current_user.id}%26state_params%3Dagent&team=#{@installed_app.configs_team_id}"
      @slack_url =  redirect_url
    end

    @teams_app = get_installed_app(Integrations::Constants::APP_NAMES[:microsoft_teams])

    if @teams_app
      owner = owners[:microsoft_teams]
      auth_waiting_key = get_channel_redis_key owner, redis_info[:auth_waiting_key]
      teams_class_names = []
      
      general_keys = redis_info[:general_keys]
      active_user_key =  get_channel_redis_key owner, general_keys[:active_users]
      authorization_user_key = get_channel_redis_key owner, general_keys[:authorized_users]
      is_teams_active = $redis_integrations.perform_redis_op("sismember", active_user_key, current_user.id)
      is_fd_authorized = $redis_integrations.perform_redis_op("sismember", authorization_user_key, current_user.id)

      teams_authorized = is_teams_active || is_fd_authorized
      teams_class_names << 'btn-primary' if teams_authorized

      auth_waiting = $redis_integrations.perform_redis_op('get', auth_waiting_key)
      unless auth_waiting
        message = is_fd_authorized ? t(:'integrations.microsoft_teams.bot_user_not_connected') : t(:'integrations.microsoft_teams.fd_user_not_connected') unless is_teams_active
        @microsoft_teams_status = get_content_tag_for_apps(message) if message
      else
        teams_class_names << 'disabled'
      end
      
      @teams_class_names = teams_class_names.join(" ")
      @teams_authorized = teams_authorized
      
      origin_info = CGI.escape("id=#{current_account.id}&portal_id=#{current_portal.id}&user_id=#{current_user.id}&state_params=agent")
      redirect_url =  "#{AppConfig['integrations_url'][Rails.env]}/auth/microsoft_teams?origin=#{origin_info}"
      @teams_url =  redirect_url
    end
  end

protected
  
  def cname
    @cname ='user'
  end
  
  def load_object
    @user = current_user
  end

  def filter_params
    if params[:user]
      params[:user].delete(:helpdesk_agent)
      params[:user].delete(:role_ids)
      params[:user].delete(:email)
      validate_phone_field_params @user
    end
    if params[:agent]
      params[:agent].delete(:user_id)
      params[:agent].delete(:occasional)
      params[:agent].delete(:ticket_permission)
    end
  end

  def agent_params
    params[:agent].permit(:signature_html)
  end

  def user_params
    if freshid_integration_enabled?
      params[:user].permit(*USER_UPDATABLE_ATTRIBUTES_FRESHID)
    else
      params[:user].permit(*USER_UPDATABLE_ATTRIBUTES)
    end
  end
end
