class SubscriptionsController < ApplicationController

  skip_before_filter :check_account_state

  
  before_filter :load_billing, :only => [ :show, :billing, :payment_info ]
  before_filter :load_subscription, :only => [ :show, :billing, :plan, :plans, :calculate_amount, :free, :convert_subscription_to_free ]
  before_filter :load_discount, :only => [ :plans, :plan, :show, :calculate_amount ]
  before_filter :load_plans, :only => [:show, :plans, :free]
  before_filter :admin_selected_tab, :only => [ :billing, :show, :edit, :plan, :cancel, :free ]
  before_filter :load_subscription_plan, :only => [:plan, :calculate_amount, :convert_subscription_to_free]
  before_filter :check_free_agent_limit, :only => [:convert_subscription_to_free]
  before_filter :check_credit_card_for_free, :only => [:plan,:plans] 
  
  filter_parameter_logging :creditcard,:password

  ssl_required :billing

  def convert_subscription_to_free
    @subscription.subscription_plan = SubscriptionPlan.find(:first, :conditions => {:name => SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]})
    @subscription.convert_to_free
    if @subscription.save
      flash[:notice] = t('plan_is_selected', :plan => @subscription.subscription_plan.name )
      redirect_to subscription_url
    else
      flash[:notice] = t('error_in_plan')
      redirect_to :back
    end
  end

  def show
  end

  def plans
    # render :layout => 'public' # Uncomment if your "public" site has a different layout than the one used for logged-in users
  end
  
  def billing
  	if request.post?
    	@address.first_name = @creditcard.first_name
      @address.last_name = @creditcard.last_name
      if @creditcard.valid? & @address.valid?
        if @subscription.store_card(@creditcard, :billing_address => @address.to_activemerchant, :ip => request.remote_ip, :charge_now => params[:charge_now])
          flash[:notice] = t('billing_info_update')
          flash[:notice] = t('card_process') if params[:charge_now].eql?("true")
          redirect_to :action => "show"
        end
      end
    end
  end

  def calculate_amount
  	@subscription_plan.discount = @discount
    @subscription.billing_cycle = params[:billing_cycle].to_i
    @subscription.plan = @subscription_plan
    @subscription.agent_limit = params[:agent_limit]
    render :partial => "calculate_amount", :locals => { :amount => @subscription.total_amount }
  end

  def plan
    @current_subscription = Subscription.find(current_account.subscription.id )
    if request.post?
      @subscription_plan.discount = @discount
      @subscription.billing_cycle = params[:billing_cycle].to_i
      @subscription.plan = @subscription_plan
      @subscription.agent_limit = params[:agent_limit]
      if @subscription.save
        #SubscriptionNotifier.deliver_plan_changed(@subscription)
      else
        load_plans        
        render :action => "plan" and return
      end
      
      if params[:agent_limit].to_i <= @subscription.free_agents and @subscription.sprout?
        convert_subscription_to_free
      else
        if !@subscription.active? or @subscription.card_number.blank?
          redirect_to :action => "billing"
        else
          flash[:notice] = t('plan_info_update')
          redirect_to :action => "show"
        end 
      end
    else
      load_plans
    end
  end

  protected
  
    def load_subscription_plan
       @subscription_plan = SubscriptionPlan.find_by_id(params[:plan_id])
       @subscription_plan ||= current_account.subscription.subscription_plan
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
      @discount = @subscription.discount unless @subscription.discount.blank?
    end
    
    def load_plans
      plans = SubscriptionPlan.current
      plans << @subscription.subscription_plan if @subscription.subscription_plan.classic?
      @plans = plans.collect {|p| p.discount = @discount; p }
    end

    def admin_selected_tab
      @selected_tab = :admin
    end  

  
    def check_free_agent_limit
      unless @subscription.eligible_for_free_plan?
        flash[:notice] = t('not_eligible_for_sprout_plan')
        redirect_to :action => "show"
      end
    end

    def check_credit_card_for_free
      if @subscription.free? and @subscription.card_number.blank?
        flash[:notice] = t('enter_billing_for_free')
        redirect_to :action => "billing"
      end
    end

end	