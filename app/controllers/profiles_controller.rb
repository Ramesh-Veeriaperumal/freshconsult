class ProfilesController < ApplicationController
  
   before_filter :require_user 
   before_filter :load_user, :only => [:edit, :change_password]
   before_filter :clean_params, :only => [:update]
   skip_before_filter :check_privilege
   ssl_required :edit
   include ModelControllerMethods

  def edit       
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @profile }
    end      
  end

  def create
  end

  def update 
     if current_user.customer?
       update_contact # Possible dead code. We have a support profiles controller to do this.
     else
       update_agent
     end  
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
    render :action => :edit
  end

def destroy
end

def update_contact
    if @obj.update_attributes(params[cname])
      flash[:notice] = t(:'flash.profile.update.success')
      redirect_to :back
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      redirect_to :action => 'edit'
    end
  
end

def update_agent
  @profile = current_user.agent
    respond_to do |format|      
      if @profile.update_attributes(params[:agent])            
          @user = current_account.users.find(@profile.user_id)          
          @user.update_attributes(params[:user])        
          format.html { redirect_to(edit_profile_url, :notice => 'Your profile has been updated successfully.') }
          format.xml  { head :ok }
      else
        format.html { redirect_to(edit_profile_url, :notice => 'oops!.. Unable to update your profile.') }
        format.xml  { render :xml => @profile.errors, :status => :unprocessable_entity }
      end    
    end    
  
end
  
def change_password    
    @check_session = current_account.user_sessions.new(:email => current_user.email, :password => params[:user][:current_password], :remember_me => false)
    if @check_session.save && reset_password 
      flash[:notice] = t(:'flash.profile.change_password.success')
      @check_session.destroy
      current_user_session.destroy
      redirect_to new_user_session_url      
    else     
      flash[:notice] = t(:'flash.profile.change_password.failure')
      if current_user.customer?
        redirect_to edit_support_profile_path 
      else
        redirect_to edit_profile_path # redirect_to used to fix breadcrums issue in Freshservice
      end
    end      
end

def reset_password
    return false if params[:user][:password] != params[:user][:password_confirmation]
    @user = current_user
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    @user.active = true #by Shan need to revisit..
    @user.save
end

def notification_read
    current_user.agent.update_attribute(:notification_timestamp, Time.new.utc)
    head 200
end

private

  def load_user
    @profile = current_user.customer? ? current_user : current_user.agent    
  end

protected

 def cname
      @cname ='user'
 end
 
 def clean_params
  if params[:user]
    params[:user].delete(:helpdesk_agent)
    params[:user].delete(:role_ids)
  end
  if params[:agent]
    params[:agent].delete(:user_id)
    params[:agent].delete(:occasional)
    params[:agent].delete(:ticket_permission)
  end
 end

end
