require 'httparty'
class SubscriptionsController < ApplicationController
  include RestrictControllerAction
  include Subscription::Currencies::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :prevent_actions_for_sandbox
  skip_before_filter :check_account_state

  before_filter :admin_selected_tab
  before_filter :load_objects, :load_subscription_plan, :cache_objects
  before_filter :load_coupon, :only => [ :calculate_amount, :plan ]
  before_filter :modify_addons_temporarily, only: [:calculate_amount, :plan]
  before_filter :load_billing, :validate_subscription, :only => :billing
  before_filter :load_freshfone_credits, :only => [:show]
  before_filter :valid_currency?, :only => :plan

  before_filter :build_subscription, :only => [ :calculate_amount, :plan ]
  before_filter :build_free_subscription, :only => :convert_subscription_to_free
  before_filter :build_paying_subscription, :only => :billing
  before_filter :check_for_subscription_errors, :except => [ :calculate_amount, :show, :calculate_plan_amount ]
  after_filter :add_event, :only => [ :plan, :billing, :convert_subscription_to_free ]

  restrict_perform :billing
  ssl_required :billing

  attr_accessor :addon_params

  CARD_UPDATE_REQUEST_LIMIT = 5
  ACTIVE = "active"
  FREE = "free"

  ADDON_CHANGES_TO_LISTEN = [Subscription::Addon::FSM_ADDON].freeze
  ADDON_PARAMS_NAMES_MAP = {
    "field_service_management": Subscription::Addon::FSM_ADDON
  }.freeze

  def calculate_amount
    scoper.set_billing_params(params[:currency])
    coupon = coupon_applicable? ? @coupon : nil
    render :partial => "calculate_amount", :locals => { :amount => scoper.total_amount(@addons, coupon),
      :discount => scoper.discount_amount(@addons, coupon) }
  end

  def calculate_plan_amount
    # render plan pricing with selected currency
    scoper.set_billing_params(params[:currency])
    render :partial => "select_new_plans", :locals => { :plans => @plans,
      :subscription => scoper, :show_all => true }
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
    @selected_plan = params['plan']
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
      # TODO: Remove force_2019_plan?() after 2019 plan launched
      plans = (current_account.force_2019_plan? ? SubscriptionPlan.plans_2019 : SubscriptionPlan.current)
      plans << scoper.subscription_plan if scoper.subscription_plan.classic?

      @subscription = scoper
      @addons = scoper.addons.dup
      @plans = plans.uniq
      @currency = scoper.currency_name
    end

    def modify_addons_temporarily
      @addon_params = params['addons'] || {}

      enabled_addon_names_from_params = ADDON_PARAMS_NAMES_MAP.map do |addon_type, addon_name|
        addon_name if addon_enabled?(addon_type)
      end.compact
      disabled_addon_names_from_params = ADDON_PARAMS_NAMES_MAP.values - enabled_addon_names_from_params

      create_new_addons_list(enabled_addon_names_from_params, disabled_addon_names_from_params)
    end

    # Not allowing add-ons if it's value is not greater than 0. Chargebee allows addons with more than 0 quantity.
    def addon_enabled?(addon_type)
      addon_params[addon_type].present? && addon_params[addon_type]['enabled'] == 'true' && addon_params[addon_type]['value'].to_i > 0
    end

    def create_new_addons_list(enabled_addon_names, disabled_addon_names)
      # Remove disabled addons to the instance variable(this doesn't remove addons from the DB).
      @addons.reject! { |addon| disabled_addon_names.include?(addon.name) }

      # Add enabled addons to the instance variable(this doesn't add addons to the DB).
      enabled_addon_names -= @addons.map(&:name) # To remove duplicates.
      addons_to_add = Subscription::Addon.where(name: enabled_addon_names)
      @addons.push(*addons_to_add)
    end

    def load_coupon
      @coupon = scoper.coupon
    end

    def load_subscription_plan
      # TODO: Remove force_2019_plan?() after 2019 plan launched
      if current_account.force_2019_plan?
        @subscription_plan = SubscriptionPlan.plans_2019.find_by_id(params[:plan_id]) if params[:plan_id].present?
      else
        @subscription_plan = SubscriptionPlan.current.find_by_id(params[:plan_id]) if params[:plan_id].present?
      end
      @subscription_plan ||= scoper.subscription_plan
    end

    def load_billing
      @creditcard = ActiveMerchant::Billing::CreditCard.new(params[:creditcard])
      @address = SubscriptionAddress.new(params[:address])
    end

    def validate_subscription
      return unless @subscription.agent_limit.blank?
      flash[:notice] = t("subscription.error.choose_plan")
      redirect_to subscription_url
    end

    def cache_objects
      @cached_subscription = Subscription.find(current_account.subscription.id)
      @cached_addons = @cached_subscription.addons.dup
    end

    #building objects
    def build_subscription
      scoper.billing_cycle = params[:billing_cycle].present? ? params[:billing_cycle].to_i : 
        SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
      scoper.plan = @subscription_plan
      scoper.agent_limit = params[:agent_limit]
      populate_addon_based_limits
      scoper.free_agents = @subscription_plan.free_agents
      @addons = scoper.applicable_addons(@addons, @subscription_plan)
    end

    def populate_addon_based_limits
      field_service_addon = addon_params['field_service_management']

      if field_service_addon.present? && field_service_addon['enabled'] == 'true'
        scoper.field_agent_limit = field_service_addon['value'].to_i
      else
        scoper.additional_info = scoper.additional_info.except(:field_agent_limit)
      end
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
      if agent_type = (scoper.chk_change_agents || scoper.chk_change_field_agents)
        Rails.logger.debug "Subscription Error::::::: #{agent_type} Limit exceeded, account id: #{current_account.id}"

        agent_count, error_class = if agent_type == Agent::SUPPORT_AGENT
          [current_account.full_time_support_agents.count, 'lesser_agents']
        else
          [current_account.field_agents_count, 'lesser_field_agents']
        end
        flash[:notice] = t("subscription.error.#{error_class}", agent_count: agent_count)
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
      addons = @addons
      !(@cached_subscription.active? and (scoper.total_amount(addons, coupon) < @cached_subscription.amount) and
        Subscription::NO_PRORATION_PERIOD_CYCLES.include?(@cached_subscription.renewal_period))
    end

    def update_features
      perform_ui_based_addon_operations
      return unless plan_changed?

      SAAS::SubscriptionEventActions.new(scoper.account, @cached_subscription, @cached_addons, features_to_skip).change_plan
      if Account.current.active_trial.present?
        Account.current.active_trial.update_result!(@cached_subscription, Account.current.subscription)
      end
    end

    # SAAS::SubscriptionEventActions will remove the BM feature corresponding to the addon if the addon get's removed.
    # For FSM, we have a usecase where zero field agent limit is possible with FSM enabled.
    # => We maintain field agent limit in chargebee through an addon and adding addon with zero quantity is not possible through chargebee.
    # So, FSM like addons(UI based addons), we are not going to remove BM in the Plans and billings flow.
    # => It is taken care in the drop_data_based_on_params method if the feature is actually removed.
    # Same case for add add-on as well. So, we need to skip them as well.
    def features_to_skip
      ADDON_PARAMS_NAMES_MAP.keys
    end

    def perform_ui_based_addon_operations
      [SAAS::SubscriptionEventActions::ADD, SAAS::SubscriptionEventActions::DROP].each do |action|
        feature_list = if action == SAAS::SubscriptionEventActions::ADD
                         addon_params.map { |feature, value| feature.to_sym if !Account.current.has_feature?(feature.to_sym) && value['enabled'] == 'true' }.compact
                       else
                         addon_params.map { |feature, value| feature.to_sym if Account.current.has_feature?(feature.to_sym) && value['enabled'] == 'false' }.compact
                       end

        next if feature_list.blank?

        Rails.logger.debug ":::::: #{action}_data_based_on_params, features to #{action}: #{feature_list.inspect}"
        action == SAAS::SubscriptionEventActions::ADD ? feature_list.each { |f| Account.current.add_feature(f) } : feature_list.each { |f| Account.current.revoke_feature(f) }
        # So, the features get updated in Saas::SubscriptionEventActions calls.
        Account.current.reload
        NewPlanChangeWorker.perform_async(features: feature_list, action: action)
      end
    end

    def plan_changed?
      scoper.subscription_plan_id != @cached_subscription.subscription_plan_id
    end

    #Events
    def subscription_info(subscription)
      subscription_attributes =
        Subscription::SUBSCRIPTION_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = subscription.safe_send(v); h }
      subscription_attributes.merge!( :next_renewal_at => subscription.next_renewal_at.to_s(:db) )
    end

    def add_event
      args = { :account_id => @subscription.account_id, :subscription_id => @subscription.id,
            :subscription_hash => subscription_info(@cached_subscription) }
      Subscriptions::SubscriptionAddEvents.perform_async(args)
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
      billing_currencies = scoper.trial? ? SUPPORTED_CURRENCIES : BILLING_CURRENCIES
      unless billing_currencies.include?(params[:currency])
        flash[:error] = t("subscription.error.invalid_currency")
        redirect_to subscription_url
      end
    end
end
