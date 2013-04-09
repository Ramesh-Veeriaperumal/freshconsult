class UsersController < ApplicationController 

  include ModelControllerMethods #Need to remove this, all we need is only show.. by Shan. to do must!
  include HelpdeskControllerMethods

  skip_before_filter :check_privilege, :only => [:revert_identity, :profile_image]
  before_filter :set_selected_tab
  skip_before_filter :load_object , :only => [ :show, :edit ]
  before_filter :load_multiple_items, :only => :block

  ##redirect to contacts
  def index
    redirect_to contacts_url
  end
    
  def new
    redirect_to new_contact_url
  end
  
  def edit
    redirect_to edit_contact_url
  end
  
  def create    
    @user = current_account.users.new #by Shan need to check later       
    if @user.signup!(params)
      #@user.deliver_activation_instructions! #Have moved it to signup! method in the model itself.
      flash[:notice] = t("user_activation_message_sent", :user_email => @user.email)
      redirect_to users_url
    else
      render :action => :new
    end
  end
  
  def block
    @items.each do |item|
      item.deleted = true 
      item.save if item.customer?
    end
    flash[:notice] = t("users_blocked_message", :users => @items.map {|u| u.name}.join(', '))
    render(:update) { |page| show_ajax_flash(page)  }
  end
  
   
  def show
    logger.debug "in users controller :: show show"
    user = current_account.all_users.find(params[:id])        
    if(user.customer? )
      redirect_to :controller =>'contacts' ,:action => 'show', :id => params[:id]    
    else    
      agent_id = current_account.all_agents.find_by_user_id(params[:id]).id
      redirect_to :controller =>'agents' ,:action => 'show', :id => agent_id    
    end
    
  end

  def profile_image
    load_object
    redirect_to (@user.avatar.nil? ? "/images/fillers/profile_blank_thumb.gif" : 
      @user.avatar.expiring_url(:thumb, 300))
  end
  
  def delete_avatar
    load_object
    @user.avatar.destroy
    render :text => "success"
  end
  
  def assume_identity
    user = current_account.users.find params[:id]

    if assume_identity_for_user(user)
      flash[:notice] = I18n.t("assumed_identity_msg", :user_name => user.name)
    else
      flash[:notice] = I18n.t("assuming_identity_not_allowed_msg")
    end
    redirect_to "/"
  end

  def revert_identity
    if(session.has_key?(:original_user))
      
      revert_current_user

      session.delete :original_user
      session.delete :assumed_user
      
      flash[:notice] = I18n.t("identity_reverted_msg")
    else
      flash[:error] = I18n.t("identity_reverted_error_msg")
    end
    redirect_to "/"
  end
 
  protected
  
    def scoper
      current_account.all_users
    end
    

    def set_selected_tab
      @selected_tab = :customers
    end
  
end