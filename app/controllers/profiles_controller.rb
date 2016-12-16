class ProfilesController < ApplicationController

  include ModelControllerMethods  
  include UserHelperMethods  
   before_filter :require_user 
   before_filter :load_profile, :only => [:edit, :change_password]
   before_filter :set_profile, :filter_params, :only => [:update]
   before_filter :load_password_policy, :check_apps ,:only => :edit
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
        redirect_to new_user_session_url     
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
      if @profile.update_attributes(params[:agent])                     
          @user.update_attributes(params[:user])        
          format.html { redirect_to(edit_profile_url, :notice => 'Your profile has been updated successfully.') }
          format.xml  { head :ok }
      else
        format.html { redirect_to(edit_profile_url, flash: { error: activerecord_error_list(@profile.errors) }) }
        format.xml  { render :xml => @profile.errors, :status => :unprocessable_entity }
      end    
    end    
  end

  def change_password_fail
    if current_user.customer?
      redirect_to edit_support_profile_path 
    else
      redirect_to edit_profile_path # redirect_to used to fix breadcrums issue in Freshservice
    end
  end

  def check_apps
    @installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:slack_v2]).first
    if @installed_app and @installed_app.configs_allow_slash_command
      @authorized = Integrations::UserCredential.where(:account_id => current_account.id, :installed_application_id => @installed_app.id,:user_id => current_user.id).first
      redirect_url =  "#{AppConfig['integrations_url'][Rails.env]}/auth/slack?origin=id%3D#{current_account.id}%26portal_id%3D#{current_portal.id}%26user_id%3D#{current_user.id}%26state_params%3Dagent&team=#{@installed_app.configs_team_id}"
      @slack_url =  redirect_url
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
end
