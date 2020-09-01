class Billing::Subscription < Billing::ChargebeeWrapper

  include Marketplace::ApiMethods
  include SubscriptionsHelper

  CUSTOMER_INFO   = { :first_name => :admin_first_name, :last_name => :admin_last_name,
                       :company => :name }

  CREDITCARD_INFO = { :number => :number, :expiry_month => :month, :expiry_year => :year,
                      :cvv => :verification_value }

  ADDRESS_INFO    = { :first_name => :first_name, :last_name => :last_name, :billing_addr1 => :address1,
                      :billing_addr2 => :address2, :billing_city => :city, :billing_state => :state,
                      :billing_country => :country, :billing_zip => :zip }

  TRIAL_PLAN_QUANTITY = "1"

  TRIAL_END = "0"

  PLANS = SubscriptionPlan::SUBSCRIPTION_PLANS.keys.freeze

  BILLING_PERIOD  = { 1 => "monthly", 3 => "quarterly", 6 => "half_yearly", 12 => "annual" }

  MAPPED_PLANS = Array.new

  PLANS.map { |plan|
    BILLING_PERIOD.each do |months, cycle_name|
      MAPPED_PLANS << [ %{#{plan}_#{cycle_name}}, plan.to_s, months ]
    end
  }  # [ [ "sprout_annual", "sprout", 12 ], ... ]


  #class methods
  def self.helpkit_plan
    Hash[*MAPPED_PLANS.map { |i| [i[0], i[1]] }.flatten]
  end

  def self.billing_cycle
    Hash[*MAPPED_PLANS.map { |i| [i[0], i[2]] }.flatten]
  end

  def self.current_plans_costs_per_agent_from_cache(currency)
    MemcacheKeys.fetch(format(MemcacheKeys::PLANS_AGENT_COSTS_BY_CURRENCY,
      currency_name: currency.name)) do
      Billing::Subscription.new.current_plans_costs_per_agent(currency)
    end
  end

  #instance methods
  def create_subscription(account, subscription_params = {})
    data = create_subscription_params(account, subscription_params)
    super(data)
  end

  def update_subscription(subscription, prorate, addons, coupon = nil, downgrade = false)
    data = (subscription_data(subscription)).merge({ :prorate => prorate })
    merge_trial_end(data, subscription)
    merge_addon_data(data, subscription, addons)
    data.merge!(:replace_addon_list => true)
    data.merge!(:coupon => coupon, :end_of_term => true) if downgrade

    result = super(subscription.account_id, data)
    subscription.subscription_term_start = Time.zone.at(result.subscription.current_term_start) if result.subscription.current_term_start.present?
    result
  end

  #estimate
  def calculate_estimate(subscription, addons, discount)
    data = create_estimate_params(subscription, addons, discount)
    create_subscription_estimate(data)
  end

  def calculate_update_subscription_estimate(subscription, addons)
    data = subscription_data(subscription).merge(:id => subscription.account_id)
    merge_addon_data(data, subscription, addons)
    attributes = cancelled_subscription?(subscription.account_id) ? { :subscription => data } :
                                { :subscription => data, :end_of_term => true }
    attributes.merge!(:replace_addon_list => true, :billing_cycles => 1)

    update_subscription_estimate(attributes)
  end

  def activate_subscription(subscription, address_details)
    data = subscription_data(subscription).merge( :trial_end => TRIAL_END )
    data = data.merge(address_details)
    data.merge!(:addons => marketplace_addons(subscription))
    ChargeBee::Subscription.update(subscription.account_id, data)
  end

  def update_admin(config)
    update_customer(config.account_id, customer_data(config.account))
  end

  def buy_day_passes(account, quantity)
    update_non_recurring_addon(day_pass_data(account, quantity))
  end

  def cancel_subscription(account, data = {})
    cancelled_subscription?(account.id) ? true : super(account.id, data)
  end

  def remove_scheduled_cancellation(account)
    ChargeBee::Subscription.remove_scheduled_cancellation(account.id)
  end

  def reactivate_subscription(subscription, data = {})
    ChargeBee::Subscription.reactivate(subscription.account_id, data)
  end

  def add_discount(account, discount_code)
    super account.id, discount_code
  end

  def offline_subscription?(account_id)
    retrieve_subscription(account_id).customer.auto_collection.eql?("off")
  end

  def cancelled_subscription?(account_id)
    retrieve_subscription(account_id).subscription.status.eql?("cancelled")
  end

  def retrieve_plan(plan_name, renewal_period = 1)
    super chargebee_plan_id(plan_name, renewal_period)
  end

  def chargebee_plan_id(plan_name, renewal_period)
    %(#{plan_name.gsub(' ','_').to_s.downcase}_#{BILLING_PERIOD[renewal_period]})
  end

  def subscription_exists?(account_id)
    begin
      retrieve_subscription(account_id)
      true
    rescue ChargeBee::APIError => error
      return false if error.http_code == 404
      NewRelic::Agent.notice_error(error)
    end
  end

  # API to check if coupon can be applied to a plan and max redemptions have not reached.
  def coupon_applicable?(subscription, coupon_code)
    begin
      result = retrieve_coupon(coupon_code)
      coupon = JSON.parse(result.coupon.to_json)["values"]

      return true if applicable_to_plan?(coupon, subscription) and can_be_redeemed?(coupon)
      false
    rescue ChargeBee::APIError => error
      return false if error.http_code == 404
      NewRelic::Agent.notice_error(error)
    end
  end

  def remove_scheduled_changes(account_id)
    super
  rescue ChargeBee::InvalidRequestError => error
    raise error unless error.error_code == 'no_scheduled_changes'
  end

  def current_plans_costs_per_agent(currency)
    chargebee_id_to_subscription_plan_name = {}
    plans_to_agent_cost = {}
    SubscriptionPlan.current_plan_names_from_cache.each do |plan_name|
      plans_to_agent_cost[plan_name] = {}
      Billing::Subscription::BILLING_PERIOD.keys.each do |billing_period|
        chargebee_plan_id = chargebee_plan_id(plan_name, billing_period)
        chargebee_id_to_subscription_plan_name[chargebee_plan_id] = plan_name
      end
    end
    plans = retrieve_plans_by_id(chargebee_id_to_subscription_plan_name.keys,
      currency.billing_site, currency.billing_api_key)
    plans.each do |plan|
      amt = (plan[:price]/plan[:period])/100
      plans_to_agent_cost[chargebee_id_to_subscription_plan_name[
        plan[:id]]][Billing::Subscription::BILLING_PERIOD[plan[:period]]] =
        format_amount(amt, currency.name)
    end
    plans_to_agent_cost
  rescue StandardError => e
    Rails.logger.error "Exception while fetching plan deatils from ChargeBee
      #{e.backtrace}"
    NewRelic::Agent.notice_error(e, description: 'Exception while fetching plan
      deatils from ChargeBee #{e.backtrace} for Account #{Account.current.id}')
  end

  def fetch_estimate_info(subscription, addons)
    addon_data = {}
    ids = []
    quantity = []
    merge_addon_data(addon_data, subscription, addons)
    addon_data[:addons].each do |addon|
      ids << addon[:id].to_s
      quantity << addon[:quantity]
    end
    addon_data[:ids] = ids
    addon_data[:quantity] = quantity
    retrieve_estimate_content(subscription, addon_data)
  end

  private
    def create_subscription_params(account, subscription_params)
      subscription_info = if subscription_params
        subscription_data(account.subscription).merge(subscription_params)
      else
        subscription_data(account.subscription)
      end
      account_info(account).merge(subscription_info)
    end

    def account_info(account)
      {
        :id => account.id,
        :customer => customer_data(account)
      }
    end

    def customer_data(account)
      data = CUSTOMER_INFO.inject({}) { |h, (k, v)| h[k] = account.safe_send(v).to_str; h }
      data.merge(:email => account.invoice_emails.first)
    end

    def subscription_data(subscription)
      {
        :plan_id => plan_code(subscription),
        :plan_quantity => subscription.agent_limit.blank? ? TRIAL_PLAN_QUANTITY : subscription.agent_limit
      }
    end

    def plan_code(subscription)
      %{#{subscription.subscription_plan.canon_name.to_s}_#{BILLING_PERIOD[subscription.renewal_period]}}
    end

    def card_info(card)
      CREDITCARD_INFO.inject({}) { |h, (k, v)| h[k] = card.safe_send(v); h }
    end

    def billing_address(address)
       ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = address.safe_send(v); h }
    end

    def day_pass_data(account, quantity)
      {
        :subscription_id => account.id,
        :addon_id => account.plan_name.to_s,
        :addon_quantity => quantity
      }
    end

    def addon_billing_params(subscription, addon)
      data = { :id => addon.billing_addon_id }
      data.merge!(:quantity => addon.billing_quantity(subscription))
      data
    end

    def merge_addon_data(data, subscription, addons)
      addon_list = addons.inject([]) do |result, addon|
        result << addon_billing_params(subscription, addon) if addon.billing_quantity(subscription).to_i > 0
        result
      end
      addon_list = addon_list + marketplace_addons(subscription)
      data.merge!(:addons => addon_list)
    end

    def merge_trial_end(data, subscription)
      extend_trial(subscription) ? data.merge!(:trial_end => extend_trial(subscription)) : data
    end

    def extend_trial(subscription)
      return retrieve_subscription(subscription.account_id).subscription.trial_end if subscription.trial?

      1.hour.from_now.to_i if subscription.suspended? and subscription.card_number.blank?
    end

    def create_estimate_params(subscription, addons, discount)
      data = subscription_data(subscription)
      merge_addon_data(data, subscription, addons)
      data.merge!(:coupon => discount)
      { :subscription => data, :end_of_term => true, :replace_addon_list => true }
    end

    def applicable_to_plan?(coupon, subscription)
      coupon["plan_ids"].blank? or coupon["plan_ids"].include?(plan_code(subscription))
    end

    def can_be_redeemed?(coupon)
      coupon["max_redemptions"].to_i.eql?(0) or
        coupon["max_redemptions"].to_i > coupon["redemptions"].to_i
    end

    def mkp_extension_id(addon_id)
      addon_id.slice(/(?<=[a-z]_)\d+(?=_|$)/).to_i
    end

    def mkp_app_units_count(addon_type, subscription)
      if addon_type == Marketplace::Constants::ADDON_TYPES[:agent]
        return subscription.new_sprout? ? subscription.account.full_time_support_agents.count : subscription.agent_limit
      else
        return Marketplace::Constants::ACCOUNT_ADDON_APP_UNITS
      end
    end

    def marketplace_addons(subscription)
      marketplace_addons = []
      begin
        all_addons = retrieve_subscription(subscription.account_id).subscription.addons
        if all_addons
          marketplace_addon_ids = all_addons.select { |addon| addon.id.include?(Marketplace::Constants::ADDON_ID_PREFIX) }.map(&:id)
          marketplace_addon_ids.each do |addon_id|
            ext = extension_details(mkp_extension_id(addon_id), Marketplace::Constants::EXTENSION_TYPE[:plug]).body
            addon_type = ext['addons'].find { |data| data['currency_code'] == subscription.account.currency_name }['addon_type']
            marketplace_addons << { :id => addon_id,
            :quantity => mkp_app_units_count(addon_type, subscription) }
          end
        end
      rescue StandardError => e
        Rails.logger.info "Exception occurred while finding marketplace_addons #{e.message}"
      ensure
        return marketplace_addons
      end
    end

end
