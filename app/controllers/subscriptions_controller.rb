class SubscriptionsController < ApplicationController
  include RestrictControllerAction

  skip_before_filter :check_account_state
  
  before_filter :admin_selected_tab
  before_filter :load_objects, :load_subscription_plan, :cache_objects
  before_filter :load_billing, :only => :billing
  before_filter :load_freshfone_credits, :only => [:show]

  before_filter :build_subscription, :only => [ :calculate_amount, :plan ]
  before_filter :build_free_subscription, :only => :convert_subscription_to_free
  before_filter :build_paying_subscription, :only => :billing
  before_filter :check_for_subscription_errors, :except => [ :calculate_amount, :show ]

  after_filter :add_event, :only => [ :plan, :billing, :convert_subscription_to_free ]

  filter_parameter_logging :creditcard, :password
  restrict_perform :billing
  ssl_required :billing

  CARD_UPDATE_REQUEST_LIMIT = 5
  NO_PRORATION_PERIOD_CYCLES = [ 1 ]
  ACTIVE = "active"
  FREE = "free"


  def calculate_amount    
    render :partial => "calculate_amount", :locals => { :amount => scoper.total_amount(@addons) }
  end

  def plan
    if request.post? and update_subscription
      update_features
      perform_next_billing_action
    else
      redirect_to subscription_url
    end
  end

  def convert_subscription_to_free
    scoper.state = FREE if scoper.card_number.blank?
    if activate_subscription
      update_features
      flash[:notice] = t('plan_is_selected', :plan => scoper.subscription_plan.name )
    else
      flash[:notice] = t('error_in_plan')
    end
    redirect_to subscription_url
  end

  def billing
    if request.post? and add_card_to_billing
      scoper.state = ACTIVE
      if activate_subscription
        flash[:notice] = t('billing_info_update')
        flash[:notice] = t('card_process') if params[:charge_now].eql?("true")
      end
      redirect_to subscription_url  
    end
  end

  def show 
  end


  private
    def admin_selected_tab
      @selected_tab = :admin
    end

    def scoper
      current_account.subscription
    end

    def billing_subscription
      @billing_subscription ||= Billing::Subscription.new
    end

    def load_objects      
      plans = SubscriptionPlan.current
      plans << scoper.subscription_plan if scoper.subscription_plan.classic?

      @subscription = scoper
      @addons = scoper.addons
      @plans = plans      
    end

    def load_subscription_plan
      @subscription_plan = SubscriptionPlan.find_by_id(params[:plan_id])
      @subscription_plan ||= scoper.subscription_plan
    end

    def load_billing
      @creditcard = ActiveMerchant::Billing::CreditCard.new(params[:creditcard])
      @address = SubscriptionAddress.new(params[:address])
    end

    def cache_objects
      @cached_subscription = Subscription.find(current_account.subscription.id)
      @cached_addons = @cached_subscription.addons.clone
    end

    #building objects
    def build_subscription
      scoper.billing_cycle = params[:billing_cycle].to_i
      scoper.plan = @subscription_plan
      scoper.agent_limit = params[:agent_limit]
      scoper.free_agents = @subscription_plan.free_agents
      @addons = scoper.applicable_addons(@addons, @subscription_plan)
    end

    def load_freshfone_credits
      @freshfone_credit = current_account.freshfone_credit
    end

    def build_free_subscription
      scoper.subscription_plan = free_plan 
      scoper.convert_to_free
    end

    def free_plan
      SubscriptionPlan.find(:first, 
        :conditions => {:name => SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]})
    end

    def build_paying_subscription
      @address.first_name = @creditcard.first_name
      @address.last_name = @creditcard.last_name
    end

    #Error Check
    def check_for_subscription_errors
      if scoper.chk_change_agents
        Rails.logger.debug "Subscription Error::::::: Agent Limit exceeded"
        flash[:notice] = t("subscription.error.lesser_agents", 
              { :agent_count => current_account.full_time_agents.count} )
        redirect_to subscription_url
      end
    end

    #chargebee and model updates
    def update_subscription
      begin
        result = billing_subscription.update_subscription(scoper, prorate?, @addons)
        scoper.set_next_renewal_at(result.subscription)
        scoper.addons = @addons
        scoper.save!
      rescue Exception => e        
        handle_error(e, t('error_in_update'))
        return false
      end
    end

    def activate_subscription
      begin
        result = billing_subscription.activate_subscription(scoper)
        scoper.set_next_renewal_at(result.subscription)
        scoper.save!
      rescue Exception => e
        handle_error(e, t('error_in_update'))
        return false
      end
    end

    def add_card_to_billing
      begin
        result = billing_subscription.store_card(@creditcard, @address, scoper)        
        scoper.set_billing_info(result.card)
        scoper.save!
      rescue Exception => e
        handle_error(e, t('card_error'))
        return false
      end
    end

    def perform_next_billing_action
      if free_plan?
        convert_subscription_to_free
      elsif card_needed_for_payment?
        redirect_to :action => "billing"
      else 
        flash[:notice] = t('plan_info_update')
        redirect_to :action => "show"
      end
    end

    def handle_error(error, custom_error_msg)
      Rails.logger.debug "Subscription Error::::: #{error}"      

      if (error_msg = error.message.match(/[A-Z][\w\W]*\./).to_s )
        flash[:notice] = error_msg #chargebee_error_message
      else
        flash[:notice] = custom_error_msg
        NewRelic::Agent.notice_error(error)
      end
    end

    def free_plan?
      scoper.agent_limit.to_i <= scoper.free_agents and scoper.sprout?
    end

    def card_needed_for_payment?
      !scoper.active? or scoper.card_number.blank?
    end

    #No proration(credit) in monthly downgrades
    def prorate?
      !(@cached_subscription.active? and (scoper.total_amount(scoper.addons) < @cached_subscription.amount) and 
        NO_PRORATION_PERIOD_CYCLES.include?(@cached_subscription.renewal_period))
    end

    def update_features
      #Check for addon changes also if customers are allowed to choose the addons.
      return if scoper.subscription_plan_id == @cached_subscription.subscription_plan_id
      SAAS::SubscriptionActions.new.change_plan(scoper.account, @cached_subscription, @cached_addons)
    end

    #Events
    def subscription_info(subscription)
      subscription_attributes = 
        Subscription::SUBSCRIPTION_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = subscription.send(v); h }
      subscription_attributes.merge!( :next_renewal_at => subscription.next_renewal_at.to_s(:db) )
    end    

    def add_event
      Resque.enqueue(Subscription::Events::AddEvent, 
        { :account_id => @subscription.account_id, :subscription_id => @subscription.id, 
          :subscription_hash => subscription_info(@cached_subscription) } )
    end

    def key
      SUBSCRIPTIONS_BILLING % { :account_id => current_account.id }
    end
 
    def perform_limit
      CARD_UPDATE_REQUEST_LIMIT
    end
 
    def perform_limit_exceeded_message
      t("subscription.error.card_update_limit_exceeded")
    end

    def admin_selected_tab
      @selected_tab = :admin
    end
    
end
