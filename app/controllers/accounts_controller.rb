class AccountsController < ApplicationController
  
  include ModelControllerMethods
  
  layout :choose_layout 
  
  skip_before_filter :set_time_zone
  
  before_filter :build_user, :only => [ :new, :create ]
  before_filter :load_billing, :only => [ :show, :new, :create, :billing, :paypal, :payment_info ]
  before_filter :load_subscription, :only => [ :show, :billing, :plan, :paypal, :plan_paypal, :plans ]
  before_filter :load_discount, :only => [ :plans, :plan, :show ]
  before_filter :build_plan, :only => [:new, :create]
  before_filter :load_plans, :only => [:show, :plans]
  before_filter :admin_selected_tab, :only => [ :billing, :show, :edit, :plan, :cancel ]
  
  ssl_required :billing
  #ssl_allowed :plans, :thanks, :canceled, :paypal
  
  before_filter :only => [:update, :destroy, :edit, :delete_logo, :delete_fav, :plan, :plans, :thanks] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :only =>  [:billing,:show,  :cancel ] do |c| 
    c.requires_permission :manage_account
  end
  
  filter_parameter_logging :creditcard,:password
  
  def show
  end   
   
  def new
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def edit

  end
  
  def check_domain
    puts "#{params[:domain]}"
    render :json => { :account_name => true }, :callback => params[:callback]
  end
   
  def signup_free
    params[:plan] = SubscriptionPlan::SUBSCRIPTION_PLANS[:premium]
    build_object
    build_user
    build_plan
   @account.time_zone = (ActiveSupport::TimeZone[params[:utc_offset].to_f]).name
    if @account.save
      render :json => { :success => true, :url => @account.full_domain }, :callback => params[:callback]
    else
      render :json => { :success => false, :errors => @account.errors.to_json }, :callback => params[:callback] 
    end    
  end
    
  def signup_google 
    base_domain = AppConfig['base_domain'][RAILS_ENV]
    logger.debug "base domain is #{base_domain}"   
    return_url = "https://signup."+base_domain+"/google/complete?domain="+params[:domain]  
    #return_url = "http://localhost:3000/google/complete?domain="+params[:domain]   
    return_url = return_url+"&callback="+params[:callback] unless params[:callback].blank?    
    url = "https://www.google.com/accounts/o8/site-xrds?hd=" + params[:domain]      
    rqrd_data = ["http://axschema.org/contact/email","http://axschema.org/namePerson/first" ,"http://axschema.org/namePerson/last"]
    re_alm = "https://*."+base_domain   
    #re_alm = "http://localhost:3000/" 
    logger.debug "return_url is :: #{return_url.inspect} and :: trusted root is:: #{re_alm.inspect} "
    authenticate_with_open_id(url,{ :required =>rqrd_data , :return_to => return_url ,:trust_root =>re_alm}) do |result, identity_url, registration| 
    end     
  end
  
  def create_account_google   
    params[:plan] = SubscriptionPlan::SUBSCRIPTION_PLANS[:premium]
    build_object
    build_user
    build_plan
    @account.time_zone = (ActiveSupport::TimeZone[params[:utc_offset].to_f]).name
    
    if @account.save       
       rediret_url = params[:call_back]+"&EXTERNAL_CONFIG=true" unless params[:call_back].blank?
       rediret_url = "https://www.google.com/a/cpanel/"+@account.google_domain if rediret_url.blank?
       redirect_to rediret_url
      #redirect to google.... else to the signup page
    else
      @call_back_url = params[:call_back]
      render :action => :signup_google 
    end    
  end

  def openid_complete	  
	  data = Hash.new
	  resp = request.env[Rack::OpenID::RESPONSE]    
    logger.debug "The resp.status is :: #{resp.status}"    
    
	  if resp.status == :success
	    session[:openid] = resp.display_identifier
	    ax_response = OpenID::AX::FetchResponse.from_success_response(resp)
	    data["email"] = ax_response.data["http://axschema.org/contact/email"].first
	    data["first_name"] = ax_response.data["http://axschema.org/namePerson/first"].first
	    data["last_name"] = ax_response.data["http://axschema.org/namePerson/last"].first      
      
      deliver_signup_page resp, data
	    
	  else
      logger.debug "Authentication failed....delivering error page" 
      deliver_error_page    
       
	  end
	   logger.debug "here is the retrieved data: #{data.inspect}"
 end
 
 def deliver_signup_page resp,data
     @open_id_url = resp.identity_url
     @call_back_url = params[:callback]   
     @account  = Account.new
     @account.domain = params[:domain].split(".")[0] 
     @account.name = @account.domain.titleize
     @account.google_domain = params[:domain]
     @user = @account.users.new   
     unless data.blank?
        @user.email = data["email"]
        @user.name = data["first_name"] +" "+data["last_name"]
      end
       
     render :action => :signup_google

 end
 
 def deliver_error_page
   render :action => :signup_google_error
 end

  def associate_google_account
    @google_domain = params[:account][:google_domain]
    @call_back_url = params[:call_back]
    @account = get_account_for_sub_domain
    if @account.blank?      
      set_account_values
      flash.now[:error] = t(:'flash.g_app.no_subdomain')
      render :signup_google and return
    end
    open_id_user = verify_open_id_user @account
    unless open_id_user.blank?
       if open_id_user.admin?   
         if @account.update_attribute(:google_domain,@google_domain)     
            rediret_url = @call_back_url+"&EXTERNAL_CONFIG=true" unless @call_back_url.blank?
            rediret_url = "https://www.google.com/a/cpanel/"+@google_domain if rediret_url.blank?
            redirect_to rediret_url            
         end        
       else
         flash.now[:error] = t(:'flash.general.insufficient_privilege.admin')
         render :associate_google         
       end
    else      
      render :associate_google
    end
  end
  def set_account_values
     @open_id_url = params[:user][:uid]  
     @call_back_url = params[:call_back]   
     @account  = Account.new
     @account.domain = params[:account][:google_domain].split(".")[0] 
     @account.name = @account.domain.titleize
     @account.google_domain = params[:account][:google_domain]
     @user = @account.users.new      
     @user.email = params[:user][:email]  
     @user.name = params[:user][:name]      
  end
  
  def get_account_for_sub_domain
    base_domain = AppConfig['base_domain'][RAILS_ENV]    
    @sub_domain = params[:account][:sub_domain]
    @full_domain = @sub_domain+"."+base_domain
    @account =  Account.find_by_full_domain(@full_domain)    
  end
 
  def associate_local_to_google
    @google_domain = params[:account][:google_domain]
    @call_back_url = params[:call_back]    
    @account = get_account_for_sub_domain    
    @check_session = @account.user_sessions.new(params[:user_session])
    if @check_session.save
       logger.debug "The session is :: #{@check_session.user}"
       if @check_session.user.admin?   
         if @account.update_attribute(:google_domain,@google_domain)
            @check_session.destroy
            rediret_url = @call_back_url+"&EXTERNAL_CONFIG=true" unless @call_back_url.blank?
            rediret_url = "https://www.google.com/a/cpanel/"+@google_domain if rediret_url.blank?
            redirect_to rediret_url
         end        
       else
         @check_session.destroy         
         flash[:notice] = t(:'flash.general.insufficient_privilege.admin')
         render :associate_google         
       end     
    else       
      flash[:notice] = t(:'flash.login.verify_credentials')
      render :associate_google
    end
    
  end
  
  def verify_open_id_user account   
    provider = 'open_id'
    identity_url = params[:user][:uid]
    email = params[:user][:email]
    @auth = Authorization.find_by_provider_and_uid_and_account_id(provider, identity_url,account.id)
    @current_user = @auth.user unless @auth.blank?
    @current_user = account.all_users.find_by_email(email) if @current_user.blank?    
  end
 
  def create    
    @account.affiliate = SubscriptionAffiliate.find_by_token(cookies[:affiliate]) unless cookies[:affiliate].blank?

    if @account.needs_payment_info?
      @address.first_name = @creditcard.first_name
      @address.last_name = @creditcard.last_name
      @account.address = @address
      @account.creditcard = @creditcard
    end
    
    if @account.save
      flash[:domain] = @account.domain
      redirect_to :action => 'thanks'
    else
      render :action => 'new'#, :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
    end
  end
  
  def update #by shan temp..
    #@account.name = params[:account][:name]
    @account.time_zone = params[:account][:time_zone]
    @account.helpdesk_name = params[:account][:helpdesk_name]
    @account.helpdesk_url = params[:account][:helpdesk_url] 
    @account.preferences = params[:account][:preferences]
    @account.ticket_display_id = params[:account][:ticket_display_id]
    
    update_logo_image  
    update_fav_icon_image
      
    
    if @account.save
      flash[:notice] = t(:'flash.account.update.success')
      redirect_to admin_home_index_path
    else
      render :action => 'edit'
    end
  end
  
  
  def plans
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def billing
    if request.post?
      if params[:paypal].blank?
        @address.first_name = @creditcard.first_name
        @address.last_name = @creditcard.last_name
        if @creditcard.valid? & @address.valid?
          if @subscription.store_card(@creditcard, :billing_address => @address.to_activemerchant, :ip => request.remote_ip, :charge_now => params[:charge_now])
            flash[:notice] = t('billing_info_update')
            flash[:notice] = t('card_process') if params[:charge_now].eql?("true")
            redirect_to :action => "show"
          end
        end
      else
        if redirect_url = @subscription.start_paypal(paypal_account_url, billing_account_url)
          redirect_to redirect_url
        end
      end
    end
  end
  
  # Handle the redirect return from PayPal
  def paypal
    if params[:token]
      if @subscription.complete_paypal(params[:token])
        flash[:notice] = 'Your billing information has been updated'
        redirect_to :action => "billing"
      else
        render :action => 'billing'
      end
    else
      redirect_to :action => "billing"
    end
  end

  def plan
    if request.post?
      subscription_plan = SubscriptionPlan.find(params[:plan_id])
      subscription_plan.discount = @discount
      @subscription.plan = subscription_plan
      @subscription.agent_limit = params[:agent_limit]
      if @subscription.save
        #SubscriptionNotifier.deliver_plan_changed(@subscription)
      else
        load_plans
        render :action => "plan" and return
      end
      
      if @subscription.state == 'trial'
        redirect_to :action => "billing"
      else
        flash[:notice] = t('plan_info_update')
        redirect_to :action => "show"
      end 
    else
      #@plans = SubscriptionPlan.find(:all, :conditions => ['id <> ?', @subscription.subscription_plan_id], :order => 'amount asc').collect {|p| p.discount = @subscription.discount; p }
      load_plans
    end
  end
  
  # Handle the redirect return from PayPal when changing plans
  def plan_paypal
    if params[:token]
      @subscription.plan = SubscriptionPlan.find(params[:plan_id])
      if @subscription.complete_paypal(params[:token])
        flash[:notice] = "Your subscription has been changed."
        SubscriptionNotifier.deliver_plan_changed(@subscription)
        redirect_to :action => "plan"
      else
        flash[:error] = "Error completing PayPal profile: #{@subscription.errors.full_messages.to_sentence}"
        redirect_to :action => "plan"
      end
    else
      redirect_to :action => "plan"
    end
  end
  

  def cancel
    if request.post? and !params[:confirm].blank?
      current_account.destroy
      #self.current_user = nil
      #reset_session
      redirect_to "http://www.freshdesk.com"
    end
  end
  
  def thanks
    redirect_to :action => "plans" and return unless flash[:domain]
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def dashboard
    render :text => 'Dashboard action, engage!', :layout => true
  end
  
  def delete_logo
    load_object
    @account.logo.destroy
    render :text => "success"
  end
  
  def delete_fav
    load_object
    @account.fav_icon.destroy
    render :text => "success"
  end

  protected
  
   def update_logo_image
    unless  params[:account][:logo_attributes].nil?
      if @account.logo.nil?
        @logo_attachment = Helpdesk::Attachment.new
        @logo_attachment.description = "logo"
        @logo_attachment.content = params[:account][:logo_attributes][:content]
        @logo_attachment.account_id = @account.id
        @account.logo = @logo_attachment
        #@account.build_logo( :description => 'logo' ,:content => params[:account][:logo_attributes][:content])
      else
        @account.logo.update_attributes(:content => params[:account][:logo_attributes][:content], :description => 'logo')
      end
    end
  end
  
  def update_fav_icon_image
   unless  params[:account][:fav_icon_attributes].nil?
      if @account.fav_icon.nil?
        @fav_attachment = Helpdesk::Attachment.new
        @fav_attachment.description = "fav_icon"
        @fav_attachment.content = params[:account][:fav_icon_attributes][:content]
        @fav_attachment.account_id = @account.id
        @account.fav_icon = @fav_attachment
        #@account.build_fav_icon(:content => params[:account][:fav_icon_attributes][:content], :description => 'fav_icon')
      else
        @account.fav_icon.update_attributes(:content => params[:account][:fav_icon_attributes][:content], :description => 'fav_icon')
      end
    end
  end
    
    def choose_layout 
      (action_name == "openid_complete" || action_name == "create_account_google" || action_name == "associate_local_to_google" || action_name == "associate_google_account") ? 'signup_google' : 'helpdesk/default'
	  end
	
    def load_object
      @obj = @account = current_account
    end
    
    def build_user
      @account.user = @user = User.new(params[:user])
    end
    
    def build_plan
      redirect_to :action => "plans" unless @plan = SubscriptionPlan.find_by_name(params[:plan])
      @plan.discount = @discount
      @account.plan = @plan
    end
    
    def redirect_url
      { :action => 'show' }
    end
    
    def load_billing
      @creditcard = ActiveMerchant::Billing::CreditCard.new(params[:creditcard])
      @address = SubscriptionAddress.new(params[:address])
    end

    def load_subscription
      @subscription = current_account.subscription
    end
    
    # Load the discount by code, but not if it's not available
    def load_discount
#     if params[:discount].blank? || !(@discount = SubscriptionDiscount.find_by_code(params[:discount])) || !@discount.available? || (@subscription.subscription_plan_id != @discount.plan_id)
#        @discount = nil
#      end     
      @discount = @subscription.discount unless @subscription.discount.blank?
    end
    
    def load_plans
      @plans = SubscriptionPlan.find(:all, :order => 'amount asc').collect {|p| p.discount = @discount; p }
    end
    
    def authorized?
      %w(new create plans canceled thanks).include?(self.action_name) || 
      (self.action_name == 'dashboard' && logged_in?) ||
      admin?
    end 
    
    def admin_selected_tab
      @selected_tab = :admin
    end

end
