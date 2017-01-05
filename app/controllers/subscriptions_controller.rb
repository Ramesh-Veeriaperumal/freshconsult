require 'httparty'
class SubscriptionsController < ApplicationController
  include RestrictControllerAction
  include Subscription::Currencies::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis

  skip_before_filter :check_account_state

  before_filter :admin_selected_tab
  before_filter :load_objects, :load_subscription_plan, :cache_objects
  before_filter :load_coupon, :only => [ :calculate_amount, :plan ]
  before_filter :load_billing, :only => :billing
  before_filter :load_freshfone_credits, :only => [:show]
  before_filter :valid_currency?, :only => :plan

  before_filter :build_subscription, :only => [ :calculate_amount, :plan ]
  before_filter :build_free_subscription, :only => :convert_subscription_to_free
  before_filter :build_paying_subscription, :only => :billing
  before_filter :check_for_subscription_errors, :except => [ :calculate_amount, :show, :calculate_plan_amount ]
  after_filter :add_event, :only => [ :plan, :billing, :convert_subscription_to_free ]

  restrict_perform :billing
  ssl_required :billing

  CARD_UPDATE_REQUEST_LIMIT = 5
  NO_PRORATION_PERIOD_CYCLES = [ 1 ]
  ACTIVE = "active"
  FREE = "free"


  def calculate_amount
    scoper.set_billing_params(params[:currency])
    coupon = coupon_applicable? ? @coupon : nil
    render :partial => "calculate_amount", :locals => { :amount => scoper.total_amount(@addons, coupon),
      :discount => scoper.discount_amount(@addons, coupon) }
  end

  def calculate_plan_amount
    # render plan pricing with selected currency
    scoper.set_billing_params(params[:currency])
    render :partial => current_account.new_pricing_launched? ? "select_new_plans" : "select_plans",
      :locals => { :plans => @plans, :subscription => scoper, :show_all => true }
  end

  def plan
    if request.post?
      switch_currency if switch_currency?
      if update_subscription
        update_features
        perform_next_billing_action
      else
        redirect_to subscription_url
      end
    end
  end

  def convert_subscription_to_free
    scoper.state = FREE if scoper.card_number.blank?
    scoper.convert_to_free if new_sprout?
    if activate_subscription
      update_features
      flash[:notice] = t('plan_is_selected', :plan => scoper.subscription_plan.display_name )
    else
      flash[:notice] = t('error_in_plan')
    end
    redirect_to subscription_url
  end

  def billing
    if request.post?
      if add_card_to_billing
        scoper.state = ACTIVE
        if activate_subscription
          flash[:notice] = t('billing_info_update')
          flash[:notice] = t('card_process') if params[:charge_now].eql?("true")
        end
        request.xhr?  ? render(:json => 200) : redirect_to(subscription_url)
      else
        redirect_to :action => "billing"
      end
    else
      result = billing_subscription.update_payment_method(current_account.id)
      @hosted_page = result.hosted_page
    end
  end

  def show
    @offline_subscription = scoper.offline_subscription?
    @invoice = scoper.subscription_invoices.last unless @offline_subscription or scoper.affiliate.present?
  end

  def request_trial_extension
    if current_account.account_additional_settings.additional_settings[:trial_extension_requested] == true
      # Trial Extension Already Requested
      render :json => {:success => true }
    else
      ticket_html = "<div>#{current_user.name} has requested for a trial extension to their Freshdesk account. Please let them know it has been done or get in touch with them if you have any questions.</div><br/><br/><p>Account URL: #{current_account.full_domain}</p>"
      ticket_html += "<p>Lead Owner: #{current_account.fresh_sales_manager_from_cache[:display_name]} (#{current_account.fresh_sales_manager_from_cache[:email]})</p>" unless current_account.fresh_sales_manager_from_cache.nil?
      ticket_html += "<p>Timezone: #{current_account.time_zone}</p>"

      ticket = {
        :helpdesk_ticket => {
          :subject => "Trial extension request from #{current_user.name} (#{current_user.email})",
          :email => current_user.email,
          :ticket_body_attributes =>{
            :description_html => ticket_html
          }
        }
      }
      resp = HTTParty.post("#{AppConfig['feedback_account'][Rails.env]}/widgets/feedback_widget?widgetType=popup", :body => ticket.to_json, :headers => { 'Content-Type' => 'application/json' })

      current_account.account_additional_settings.additional_settings[:trial_extension_requested] = true
      current_account.account_additional_settings.save if resp.code == 200
      render :json => {:success => true }
    end
  end
  
  def request_special_pricing
    if !scoper.special_pricing_requested? and current_account.created_at > Subscription::ELIGIBLE_LIMIT
      UserNotifier.notify_special_pricing(current_account)
      set_others_redis_key(special_pricing_key, Time.zone.now, 86400 * 60)
    end
    render :json => 200
  end



  private
    def admin_selected_tab
      @selected_tab = :admin
    end

    def scoper
      current_account.subscription
    end

    def billing_subscription
      Billing::Subscription.new
    end

    def load_objects
      plans = (current_account.new_pricing_launched? ? SubscriptionPlan.current : SubscriptionPlan.previous_plans)
      plans << scoper.subscription_plan if scoper.subscription_plan.classic?

      @subscription = scoper
      @addons = scoper.addons
      @plans = plans.uniq
      @currency = scoper.currency_name
    end

    def load_coupon
      @coupon = scoper.coupon
    end

    def load_subscription_plan
      if current_account.new_pricing_launched?
        @subscription_plan = SubscriptionPlan.current.find_by_id(params[:plan_id]) if params[:plan_id].present?
      else
        @subscription_plan = SubscriptionPlan.previous_plans.find_by_id(params[:plan_id]) if params[:plan_id].present?
      end
      @subscription_plan ||= scoper.subscription_plan
    end

    def load_billing
      @creditcard = ActiveMerchant::Billing::CreditCard.new(params[:creditcard])
      @address = SubscriptionAddress.new(params[:address])
    end

    def cache_objects
      @cached_subscription = Subscription.find(current_account.subscription.id)
      @cached_addons = @cached_subscription.addons.dup
    end

    #building objects
    def build_subscription
      scoper.billing_cycle = (params[:billing_cycle].present? ? params[:billing_cycle].to_i : 1)
      scoper.plan = @subscription_plan
      scoper.agent_limit = params[:agent_limit]
      scoper.free_agents = @subscription_plan.free_agents
      @addons = scoper.applicable_addons(@addons, @subscription_plan)
    end

    def load_freshfone_credits
      @freshfone_credit = current_account.freshfone_credit || Freshfone::Credit.new
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
        coupon = coupon_applicable? ? @coupon : nil
        result = billing_subscription.update_subscription(scoper, prorate?, @addons)
        unless result.subscription.coupon == coupon
          billing_subscription.add_discount(scoper.account, coupon)
        end
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
        billing_address = @customer_details.nil? ? {} : billing_address(@customer_details.card)
        result = billing_subscription.activate_subscription(scoper, billing_address)
        scoper.set_next_renewal_at(result.subscription)
        scoper.save!
      rescue Exception => e
        handle_error(e, t('error_in_update'))
        return false
      end
    end

    def billing_address(card_details)
      {
        :billing_address =>
        {
          :first_name => card_details.first_name,
          :last_name => card_details.last_name,
          :line1 => "#{card_details.billing_addr1} #{card_details.billing_addr2}",
          :city => card_details.billing_city,
          :state => card_details.billing_state,
          :zip => card_details.billing_zip,
          :country => card_details.billing_country
        }
      }
    end

    def add_card_to_billing
      begin
        @customer_details = billing_subscription.retrieve_subscription(current_account.id)
        scoper.set_billing_info(@customer_details.card)
        scoper.save!
      rescue Exception => e
        handle_error(e, t('card_error'))
        return false
      end
    end

    def perform_next_billing_action
      if free_plan? or new_sprout?
        convert_subscription_to_free
      elsif scoper.trial? && params["plan_switch"]
        flash[:notice] = t('plan_info_update')
        coupon = coupon_applicable? ? @coupon : nil
        if request.xhr?
          render :partial => "calculate_amount",
                    :locals => {
                      :amount => scoper.total_amount(@addons, coupon),
                      :discount => scoper.discount_amount(@addons, coupon)
                    }
        else
          redirect_to :action => "show"
        end
      elsif card_needed_for_payment?
        redirect_to :action => "billing"
      else
        flash[:notice] = t('plan_info_update')
        redirect_to :action => "show"
      end
    end

    def handle_error(error, custom_error_msg)
      Rails.logger.debug "Subscription Error::::: #{error}"

      if (error_msg = error.json_obj[:error_msg].split(/error_msg/).last.sub(/http.*/,""))
        flash[:notice] = error_msg #chargebee_error_message
      else
        flash[:notice] = custom_error_msg
        NewRelic::Agent.notice_error(error)
      end
    end

    def free_plan?
      scoper.agent_limit.to_i <= scoper.free_agents and scoper.sprout?
    end
    
    def new_sprout?
      scoper.new_sprout?
    end

    def card_needed_for_payment?
      !scoper.active? or scoper.card_number.blank?
    end

    #No proration(credit) in monthly downgrades
    def prorate?
      coupon = coupon_applicable? ? @coupon : nil
      !(@cached_subscription.active? and (scoper.total_amount(scoper.addons, coupon) < @cached_subscription.amount) and
        NO_PRORATION_PERIOD_CYCLES.include?(@cached_subscription.renewal_period))
    end

    def update_features
      #Check for addon changes also if customers are allowed to choose the addons.
      return if scoper.subscription_plan_id == @cached_subscription.subscription_plan_id
      SAAS::SubscriptionActions.new.change_plan(scoper.account, @cached_subscription, @cached_addons)
      SAAS::SubscriptionEventActions.new(scoper.account, @cached_subscription, @cached_addons).change_plan if current_account.new_pricing_launched?
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

    #switch_currency
    def switch_currency?
      !current_account.has_credit_card? and scoper.subscription_payments.count.zero? and
      (scoper.trial? or scoper.suspended?) and !(@currency == params[:currency])
    end

    def switch_currency
      # cancel subscription in old site and clone the subscription in the new site
      data = fetch_migration_data
      billing_subscription.cancel_subscription(scoper.account)
      scoper.set_billing_params(params[:currency])
      clone_subscription(data)
      scoper.save
    end

    def clone_subscription(data)
      if billing_subscription.subscription_exists?(scoper.account_id)
        billing_subscription.reactivate_subscription(scoper, data)
      else
        billing_subscription.create_subscription(scoper.account, data)
      end
    end

    def fetch_migration_data
      data = billing_subscription.retrieve_subscription(scoper.account_id)
      {
        :trial_end => scoper.suspended? ? 1.hour.from_now.to_i : data.subscription.trial_end,
        :coupon => data.subscription.coupon
      }
    end

    def coupon_applicable?
      @coupon.blank? ? false : billing_subscription.coupon_applicable?(@subscription, @coupon)
    end

    def valid_currency?
      unless BILLING_CURRENCIES.include?(params[:currency])
        flash[:error] = t("subscription.error.invalid_currency")
        redirect_to subscription_url
      end
    end
    
    def special_pricing_key
      SUBSCRIPTIONS_PRICING_REQUEST % {:account_id => current_account.id, :user_id => User.current.id}
    end
end
