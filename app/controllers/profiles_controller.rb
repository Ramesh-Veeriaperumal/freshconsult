class ProfilesController < ApplicationController
  
   include ModelControllerMethods
   
  def index
  end

  def show
  end

  def new
  end

  def edit       
   
    if current_user.customer?
      @profile = User.find(params[:id])
    else
       @profile = Agent.find_by_user_id(params[:id]) 
    end
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @profile }
    end      
  end

  def create
  end

  def update    
     if current_user.customer?
       update_contact
     else
       update_agent
     end
  
  end
  
def destroy
end

def update_contact
  
    company_name = params[:user][:customer]
    unless company_name.empty? 
     company = current_account.customers.find_or_create_by_name(company_name) 
     @obj.customer_id = company.id
    else
      @obj.customer_id = nil
    end
    if @obj.update_attributes(params[cname])
      flash[:notice] = "Your profile has been updated."
      redirect_to :back
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      redirect_to :action => 'edit'
    end
  
end

def update_agent
  
  @profile = Agent.find_by_user_id(params[:id])
    respond_to do |format|      
      if @profile.update_attributes(params[:agent])            
          @user = User.find(@profile.user_id)          
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
    if @check_session.save      
      reset_password 
      flash[:notice] = "Password successfully updated. Please login again"
      @check_session.destroy
      current_user_session.destroy
      redirect_to new_user_session_url      
    else     
      flash[:notice] = "Unable to change your password, Please check your current password"
      redirect_to :action => :edit
    end
      
end

def reset_password
    @user = User.find(params[:id])  
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    @user.active = true #by Shan need to revisit..
    @user.save
end
  

protected

 def cname
      @cname ='user'
 end
 

end
