class ProfilesController < ApplicationController

  include ModelControllerMethods  
  include UserHelperMethods  
   before_filter :require_user 
   before_filter :load_profile, :only => [:edit, :change_password]
   before_filter :set_profile, :filter_params, :only => [:update]
   before_filter :load_password_policy, :only => :edit
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
    flash[:error] = @user.errors.full_messages.join("<br/>").html_safe if @user.errors.any?
    result
  end
  
  def destroy
  end

  def notification_read
    current_user.agent.update_attribute(:notification_timestamp, Time.new.utc)
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
        format.html { redirect_to(edit_profile_url, :notice => 'oops!.. Unable to update your profile.') }
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
