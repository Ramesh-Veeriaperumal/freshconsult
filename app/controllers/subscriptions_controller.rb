class SubscriptionsController < ApplicationController

  skip_before_filter :check_account_state

  before_filter { |c| c.requires_permission :manage_account }
  
  before_filter :load_billing, :only => [ :show, :billing, :payment_info ]
  before_filter :load_subscription, :only => [ :show, :billing, :plan, :plans, :calculate_amount, :free, :convert_subscription_to_free ]
  before_filter :load_plans, :only => [:show, :plans, :free]
  before_filter :admin_selected_tab, :only => [ :billing, :show, :edit, :plan, :cancel, :free ]
  before_filter :load_subscription_plan, :only => [:plan, :calculate_amount, :convert_subscription_to_free]
  before_filter :check_free_agent_limit, :only => [:convert_subscription_to_free]
  before_filter :check_credit_card_for_free, :only => [:plan,:plans]
  before_filter :billing_subscription, :only => [:plan, :billing, :calculate_amount, :convert_subscription_to_free]
  
  after_filter :add_event, :only => [ :plan, :billing, :convert_subscription_to_free ]

  filter_parameter_logging :creditcard,:password

  ssl_required :billing

  NO_PRORATION_PERIOD_CYCLES = [ 1 ]

  ACTIVE = "active"

  def convert_subscription_to_free
    @subscription.subscription_plan = SubscriptionPlan.find(:first, :conditions => {:name => SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]})
    @subscription.convert_to_free

    response = billing_subscription.activate_subscription(@subscription)
    
    if response and @subscription.save
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
      @subscription.state = ACTIVE

      begin
        unless current_account.subscription.chk_change_agents
          billing_subscription.store_card(@creditcard, @address, @subscription)
        end
      rescue Exception => e
        flash[:notice] = t('card_error')
        flash[:notice] = e.message.match(/[A-Z][\w\W]*\./).to_s if e.message
        redirect_to :action => "billing" and return
      end

      begin
        unless current_account.subscription.chk_change_agents
          response = billing_subscription.activate_subscription(@subscription)
        end
      rescue Exception => e
        flash[:notice] = e.message.match(/[A-Z][\w\W]*\./).to_s if e.message
        redirect_to :action => "billing" and return
      end

      if response and @subscription.save
        flash[:notice] = t('billing_info_update')
        flash[:notice] = t('card_process') if params[:charge_now].eql?("true")
      else
        flash[:notice] = t("subscription.error.lesser_agents", 
              {:agent_count => current_account.full_time_agents.count}) if current_account.subscription.chk_change_agents 
      end

      redirect_to :action => "show"
    end
  end

  def calculate_amount
    @subscription.billing_cycle = params[:billing_cycle].to_i
    @subscription.plan = @subscription_plan
    @subscription.agent_limit = params[:agent_limit]
    @subscription.free_agents = @subscription_plan.free_agents
    
    render :partial => "calculate_amount", :locals => { :amount => @subscription.total_amount }
  end

  def plan
    @current_subscription = Subscription.find(current_account.subscription.id )
    
    if request.post?
      @subscription.billing_cycle = params[:billing_cycle].to_i
      @subscription.plan = @subscription_plan
      @subscription.agent_limit = params[:agent_limit]
      @subscription.free_agents = @subscription_plan.free_agents
      
      begin
        unless current_account.subscription.chk_change_agents
          billing_subscription.update_subscription(@subscription, prorate?)
        end
      rescue Exception => e
        flash[:notice] = t('error_in_update')
        flash[:notice] = e.message.match(/[A-Z][\w\W]*\./).to_s if e.message
        redirect_to subscription_url and return
      end
      
      if @subscription.save
        #SubscriptionNotifier.deliver_plan_changed(@subscription)    
      else
        load_plans        
        render :action => "plan" and return
      end
      
      if @subscription.agent_limit.to_i <= @subscription.free_agents and @subscription.sprout?
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
      @cached_subscription = Subscription.find(current_account.subscription.id) if current_account.subscription
      @subscription = current_account.subscription
    end
    
    def load_plans
      plans = SubscriptionPlan.current
      plans << @subscription.subscription_plan if @subscription.subscription_plan.classic?
      @plans = plans
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

    def billing_subscription
      @billing_subscription ||= begin
          Billing::Subscription.new
      end 
    end

    def prorate?
      !(@cached_subscription.active? and (@subscription.total_amount < @cached_subscription.amount) and 
        NO_PRORATION_PERIOD_CYCLES.include?(@cached_subscription.renewal_period))
    end

    def subscription_info(subscription)
      subscription_attributes = Subscription::SUBSCRIPTION_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = subscription.send(v); h }
      subscription_attributes.merge!( :next_renewal_at => subscription.next_renewal_at.to_s(:db) )
    end    

    def add_event
      Resque.enqueue(Subscription::Events::AddEvent, 
        { :account_id => @subscription.account_id, :subscription_id => @subscription.id, 
          :subscription_hash => subscription_info(@cached_subscription) } )
    end

end 
