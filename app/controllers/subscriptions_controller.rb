require 'httparty'
class SubscriptionsController < ApplicationController
  include RestrictControllerAction
  include Subscription::Currencies::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Admin::AdvancedTicketing::FieldServiceManagement::CustomFieldValidator
  include Freshcaller::JwtAuthentication
  include Freshcaller::CreditsHelper
  include SubscriptionsHelper
  include Billing::OmniSubscriptionUpdateMethods

  before_filter :prevent_actions_for_sandbox
  skip_before_filter :check_account_state

  before_filter :admin_selected_tab
  before_filter :load_objects, :load_subscription_plan, :cache_objects
  before_filter :load_coupon, :only => [:calculate_amount, :plan, :billing]
  before_filter :modify_addons_temporarily, only: [:calculate_amount, :plan]
  before_filter :load_billing, :validate_subscription, :only => :billing
  before_filter :valid_currency?, :only => :plan
  before_filter :check_fsm_requirements, :only =>[:plan] , if: -> {fsm_addon_present_in_request?}

  before_filter :build_subscription, :only => [ :calculate_amount, :plan ]
  before_filter :build_free_subscription, :only => :convert_subscription_to_free
  before_filter :build_paying_subscription, :only => :billing
  before_filter :validate_agents, :validate_fsm_agents, :validate_multi_product, :redirect_on_validation_error, except: [:calculate_amount, :show, :calculate_plan_amount]
  after_filter :add_event, :only => [ :plan, :billing, :convert_subscription_to_free ]

  restrict_perform :billing
  ssl_required :billing

  attr_accessor :addon_params

  CARD_UPDATE_REQUEST_LIMIT = 5
  ACTIVE = "active"
  FREE = "free"

  ADDON_CHANGES_TO_LISTEN = [Subscription::Addon::FSM_ADDON].freeze

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
    convert_to_free_plan(true)
  end

  def billing
    scoper.total_amount(scoper.addons, @coupon) if coupon_applicable?
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
    @reseller_paid_account = scoper.reseller_paid_account?
    @invoice = scoper.subscription_invoices.last unless @offline_subscription || scoper.affiliate.present? || @reseller_paid_account
    @freshcaller_credit_info = fetch_freshcaller_credit_info if current_account.freshcaller_account.present? && @omni_account
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

  def cancel_request
    status = :not_found
    if scoper.subscription_request.present?
      status = :no_content if scoper.subscription_request.destroy
    elsif current_account.launched?(:downgrade_policy) && current_account.account_cancellation_requested?
      status = :no_content if current_account.kill_scheduled_account_cancellation
    end
    head status
  end

  private
    def convert_to_free_plan(need_feature_update)
      scoper.state = FREE if scoper.card_number.blank?
      scoper.convert_to_free if new_sprout?
      if activate_subscription
        update_features if need_feature_update
        flash[:notice] = t('plan_is_selected', :plan => scoper.subscription_plan.display_name)
      else
        flash[:notice] = t('error_in_plan')
      end
      redirect_to subscription_url
    end

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
      Rails.logger.debug "FSM already enabled for account #{current_account.id} :: #{current_account.field_service_management_enabled?}"
      # TODO: Remove force_2020_plan?() after 2020 plan launched
      @omni_account = current_account.omni_bundle_account?
      if @omni_account
        plans = SubscriptionPlan.omni_channel_plan
      else
        plans = (current_account.force_2020_plan? ? SubscriptionPlan.plans_2020 : SubscriptionPlan.current)
        plans << scoper.subscription_plan if scoper.subscription_plan.classic?
      end
      @subscription = scoper
      @addons = scoper.addons.dup
      @plans = plans.uniq
      @currency = scoper.currency_name
      @not_eligible_for_omni_upgrade = current_account.not_eligible_for_omni_conversion?
    end

    def modify_addons_temporarily
      @addon_params = params['addons'] || {}
      enabled_addon_names_from_params = SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.map do |addon_name, addon_type|
        addon_name if addon_enabled?(addon_type)
      end.compact
      disabled_addon_names_from_params = SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.keys - enabled_addon_names_from_params
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
      @coupon = scoper.fetch_fdfs_discount_coupon || scoper.coupon
    end

    def load_subscription_plan
      if params[:plan_id].present?
        # TODO: Remove force_2020_plan?() after 2020 plan launched
        if current_account.force_2020_plan?
          @subscription_plan = SubscriptionPlan.plans_2020.find_by_id(params[:plan_id])
        else
          @subscription_plan = SubscriptionPlan.current.find_by_id(params[:plan_id])
          # Allow subscription to be updated to existing plan omni variant. eg. Estate Jan 19 to Estate Omni Jan 19
          current_plan_omni_variant = scoper.subscription_plan.omni_plan_variant if @subscription_plan.nil?
          if scoper.subscription_plan.classic && current_plan_omni_variant && current_plan_omni_variant.id.to_s == params[:plan_id]
            @subscription_plan = current_plan_omni_variant
          end
        end
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
      scoper.billing_cycle = params[:billing_cycle].present? ? params[:billing_cycle].to_i : SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
      scoper.plan = @subscription_plan
      scoper.agent_limit = params[:agent_limit]
      populate_addon_based_limits
      scoper.free_agents = @subscription_plan.free_agents
      @addons = scoper.applicable_addons(@addons, @subscription_plan)
    end

    def construct_subscription_request(next_renewal_at)
      downgrade_request = scoper.subscription_request.nil? ? scoper.build_subscription_request : scoper.subscription_request
      downgrade_request.plan_id = scoper.plan_id
      downgrade_request.renewal_period = scoper.renewal_period
      downgrade_request.agent_limit = scoper.agent_limit
      downgrade_request.fsm_field_agents = scoper.field_agent_limit
      downgrade_request.next_renewal_at = Time.at(next_renewal_at).to_datetime.utc
      downgrade_request.from_plan = scoper.present_subscription.subscription_plan_from_cache
      downgrade_request.fsm_downgrade = scoper.present_subscription.field_agent_limit.present? && scoper.field_agent_limit.blank?
      downgrade_request
    end

    def populate_addon_based_limits
      field_service_addon = addon_params['field_service_management']

      if field_service_addon.present? && field_service_addon['enabled'] == 'true'
        scoper.field_agent_limit = field_service_addon['value'].to_i
      else
        scoper.additional_info = scoper.additional_info.except(:field_agent_limit)
      end
    end

    def build_free_subscription
      scoper.subscription_plan = free_plan
      scoper.convert_to_free
    end

    def free_plan
      SubscriptionPlan.where(name: SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]).first
    end

    def build_paying_subscription
      @address.first_name = @creditcard.first_name
      @address.last_name = @creditcard.last_name
    end

    def validate_agents
      scoper.verify_agent_limit
    end

    def validate_fsm_agents
      scoper.verify_agent_field_limit
    end

    def validate_multi_product
      scoper.verify_unlimited_multi_product
    end

    def redirect_on_validation_error
      errors = current_account.subscription.errors.messages[:base]
      return if errors.blank?

      flash[:notice] = construct_subscription_error_msgs(errors)
      redirect_to subscription_url if flash[:notice].present?
    end

    #chargebee and model updates
    def update_subscription
      coupon = coupon_applicable? ? @coupon : nil
      if scoper.downgrade?
        flash[:notice] = t('subscription_request_info_update') if scoper.subscription_request.present?
        scoper.convert_to_free if new_sprout?
        scoper.total_amount(@addons, coupon_applicable? ? @coupon : nil)
        response = billing_subscription.update_subscription(scoper, false, @addons, coupon, true)
        construct_subscription_request(response.subscription.current_term_end).save!
        return false
      else
        flash[:notice] = t('subscription_info_update') if current_account.launched?(:downgrade_policy) && scoper.subscription_request.present?
        current_account.delete_account_cancellation_requested_time_key if scoper.suspended? && current_account.launched?(:downgrade_policy) && current_account.account_cancellation_requested?
        result = billing_subscription.update_subscription(scoper, prorate?, @addons)
        if Account.current.omni_bundle_account?
          chargebee_params = construct_payload_for_ui_update(result)
          Billing::FreshcallerSubscriptionUpdate.perform_async(chargebee_params)
          Billing::FreshchatSubscriptionUpdate.perform_async(chargebee_params)
        end
        scoper.subscription_request.destroy if scoper.subscription_request.present?
        billing_subscription.add_discount(scoper.account, coupon) unless [result.subscription.coupon, SubscriptionConstants::FDFSBUNDLE].include?(coupon)
        scoper.set_next_renewal_at(result.subscription)
        scoper.addons = @addons
        scoper.save!
      end
    rescue StandardError => e
      handle_error(e, t('error_in_update'))
      return false
    end

    def activate_subscription
      begin
        billing_address = @customer_details.nil? ? {} : billing_address(@customer_details.card)
        billing_subscription.add_discount(scoper.account, @coupon) if coupon_applicable? && @coupon == SubscriptionConstants::FDFSBUNDLE
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
        convert_to_free_plan(false)
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
        flash[:notice] = t('plan_info_update') unless flash[:notice]
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

      Rails.logger.info "Calling change_plan for Account :: #{scoper.account.inspect} ;
            new_plan : #{scoper.account.subscription} ; old_plan : #{@cached_subscription.inspect}"
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
      SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.values.uniq.map(&:to_sym)
    end

    def perform_ui_based_addon_operations
      [SAAS::SubscriptionEventActions::ADD, SAAS::SubscriptionEventActions::DROP].each do |action|
        feature_list = if action == SAAS::SubscriptionEventActions::ADD
                         addon_params.map { |feature, value| feature.to_sym if !scoper.account.has_feature?(feature.to_sym) && value['enabled'] == 'true' }.compact
                       else
                         addon_params.map { |feature, value| feature.to_sym if scoper.account.has_feature?(feature.to_sym) && value['enabled'] == 'false' }.compact
                       end

        next if feature_list.blank?

        Rails.logger.debug ":::::: #{action}_data_based_on_params, features to #{action}: #{feature_list.inspect}"
        action == SAAS::SubscriptionEventActions::ADD ? feature_list.each { |f| scoper.account.add_feature(f) } : feature_list.each { |f| scoper.account.revoke_feature(f) }
        # So, the features get updated in Saas::SubscriptionEventActions calls.
        Account.current.reload
        NewPlanChangeWorker.perform_async(features: feature_list, action: action) unless plan_changed?
      end
    end

    def plan_changed?
      scoper.subscription_plan_id != @cached_subscription.subscription_plan_id
    end

    #Events
    def subscription_info(subscription)
      subscription_attributes =
        Subscription::SUBSCRIPTION_ATTRIBUTES.inject({}) { |h, (k, v)| h[k] = subscription.safe_send(v); h }
      subscription_attributes.merge!(next_renewal_at: subscription.next_renewal_at.to_s(:db))
    end

    def add_event
      args = { account_id: @subscription.account_id, subscription_id: @subscription.id,
               subscription_hash: subscription_info(@cached_subscription) }
      args.merge!(current_user_id: current_user.id) if current_user.present?
      if current_account.launched?(:downgrade_policy)
        args[:requested_subscription_hash] = subscription_info(@subscription)
        args[:requested_subscription_hash][:is_downgrade] = scoper.downgrade?
        args[:requested_subscription_hash][:field_agent_limit] = scoper.subscription_request.present? ? scoper.subscription_request.fsm_field_agents : nil
        args[:subscription_hash][:subscription_term_start] = @subscription.subscription_term_start
        args[:subscription_hash][:field_agent_limit] = @cached_subscription.additional_info[:field_agent_limit]
      end
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

    def fsm_addon_present_in_request?
      fsm_addon = addon_params['field_service_management']
      fsm_addon.present? && fsm_addon['enabled'] == 'true'
    end

    def check_fsm_requirements
      return true if Account.current.field_service_management_enabled?

      unless fsm_artifacts_available?
        flash[:notice] = t('fsm_requirements_not_met')
        redirect_to subscription_url
      end
    end
end
