class AccountsController < ApplicationController
  
  include ModelControllerMethods
  
  skip_before_filter :set_time_zone
  
  before_filter :build_user, :only => [:new, :create,:signup_free]
  before_filter :load_billing, :only => [ :new, :create, :billing, :paypal ]
  before_filter :load_subscription, :only => [ :billing, :plan, :paypal, :plan_paypal ]
  before_filter :load_discount, :only => [ :plans, :plan, :new, :create ]
  before_filter :build_plan, :only => [:new, :create]
  
  #ssl_required :billing, :cancel, :new, :create #by Shan temp
  #ssl_allowed :plans, :thanks, :canceled, :paypal
  
   
  def new
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def check_domain
    puts "#{params[:domain]}"
    render :json => { :account_name => true }, :callback => params[:callback]
  end
   
  def signup_free
    params[:plan] = SubscriptionPlan::SUBSCRIPTION_PLANS[:premium]
    build_object
    build_plan
   @account.time_zone = (ActiveSupport::TimeZone[params[:utc_offset].to_f]).name
    if @account.save
      render :json => { :success => true, :url => @account.full_domain }, :callback => params[:callback]
    else
      render :json => { :success => false, :errors => @account.errors.to_json }, :callback => params[:callback] 
    end
    
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
    @account.name = params[:account][:name]
    @account.time_zone = params[:account][:time_zone]
    @account.helpdesk_name = params[:account][:helpdesk_name]
    @account.helpdesk_url = params[:account][:helpdesk_url] 
    @account.preferences = params[:account][:preferences]
    @account.ticket_display_id = params[:account][:ticket_display_id]
   
    update_logo_image  
    update_fav_icon_image
      
    
    if @account.save
      flash[:notice] = "Your account details have been updated."
      redirect_to admin_home_path
    else
      render :action => 'edit'
    end
  end
  
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
  
  def plans
    @plans = SubscriptionPlan.find(:all, :order => 'amount desc').collect {|p| p.discount = @discount; p }
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def billing
    if request.post?
      if params[:paypal].blank?
        @address.first_name = @creditcard.first_name
        @address.last_name = @creditcard.last_name
        if @creditcard.valid? & @address.valid?
          if @subscription.store_card(@creditcard, :billing_address => @address.to_activemerchant, :ip => request.remote_ip)
            flash[:notice] = "Your billing information has been updated."
            redirect_to :action => "billing"
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
      @subscription.plan = SubscriptionPlan.find(params[:plan_id])

      # PayPal subscriptions must get redirected to PayPal when
      # changing the plan because a new recurring profile needs
      # to be set up with the new charge amount.
      if @subscription.paypal?
        # Purge the existing payment profile if the selected plan is free
        if @subscription.amount == 0
          logger.info "FREE"
          if @subscription.purge_paypal
            logger.info "PAYPAL"
            flash[:notice] = "Your subscription has been changed."
            SubscriptionNotifier.deliver_plan_changed(@subscription)
          else
            flash[:error] = "Error deleting PayPal profile: #{@subscription.errors.full_messages.to_sentence}"
          end
          redirect_to :action => "plan" and return
        else
          if redirect_url = @subscription.start_paypal(plan_paypal_account_url(:plan_id => params[:plan_id]), plan_account_url)
            redirect_to redirect_url and return
          else
            flash[:error] = @subscription.errors.full_messages.to_sentence
            redirect_to :action => "plan" and return
          end
        end
      end
      
      if @subscription.save
        flash[:notice] = "Your subscription has been changed."
        SubscriptionNotifier.deliver_plan_changed(@subscription)
      else
        flash[:error] = "Error updating your plan: #{@subscription.errors.full_messages.to_sentence}"
      end
      redirect_to :action => "plan"
    else
      @plans = SubscriptionPlan.find(:all, :conditions => ['id <> ?', @subscription.subscription_plan_id], :order => 'amount desc').collect {|p| p.discount = @subscription.discount; p }
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
      self.current_user = nil
      reset_session
      redirect_to :action => "canceled"
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
  
    def load_object
      @obj = @account = current_account
    end
    
    def build_user
      logger.debug params[:user]
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
      if params[:discount].blank? || !(@discount = SubscriptionDiscount.find_by_code(params[:discount])) || !@discount.available?
        @discount = nil
      end
    end
    
    def authorized?
      %w(new create plans canceled thanks).include?(self.action_name) || 
      (self.action_name == 'dashboard' && logged_in?) ||
      admin?
    end 
        
end
