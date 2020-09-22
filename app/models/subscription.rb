class Subscription < ActiveRecord::Base
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::SubscriptionPlan
  include Onboarding::OnboardingRedisMethods
  include SubscriptionsHelper

  self.primary_key = :id
  SUBSCRIPTION_TYPES = ["active", "trial", "free", "suspended"]

  AGENTS_FOR_FREE_PLAN = 3

  TRIAL_DAYS = 21

  ANNUAL_PERIOD = 12

  SUBSCRIPTION_ATTRIBUTES = { :account_id => :account_id, :amount => :amount, :state => :state,
                              :subscription_plan_id => :subscription_plan_id, :agent_limit => :agent_limit,
                              :free_agents => :free_agents, :renewal_period => :renewal_period,
                              :subscription_discount_id => :subscription_discount_id,
                              :usd_equivalent => :usd_equivalent, :subscription_term_start => :subscription_term_start,
                              :additional_info => :additional_info }

  ADDRESS_INFO = { :first_name => :first_name, :last_name => :last_name, :address1 => :billing_addr1,
                  :address2 => :billing_addr2, :city => :billing_city, :state => :billing_state,
                  :country => :billing_country, :zip => :billing_zip  }

  FRESHCHAT_PLANS = ProductPlansConfig[:freshchat_plans].freeze

  FRESHMARKETER_FILEDS = ["state", "next_renewal_at", "renewal_period", "amount", "subscription_plan_id", "agent_limit"]

  FRESHCALLER_PLAN_MAPPING = ProductPlansConfig[:freshcaller_plan_mapping].freeze

  FRESHCHAT_PLAN_MAPPING = ProductPlansConfig[:freshchat_plan_mapping].freeze

  ACTIVE = "active"
  TRIAL = "trial"
  FREE = "free"
  SUSPENDED = "suspended"

  NO_PRORATION_PERIOD_CYCLES = [SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]].freeze

  AUTO_COLLECTION = {
    'on' => true,
    'off' => false
  }.freeze

  concerned_with :presenter, :callbacks

  publishable on: [:update]

  belongs_to :account
  belongs_to :subscription_plan
  has_one :subscription_request
  has_many :subscription_payments
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  has_one :billing_address,:class_name => 'Address',:as => :addressable,:dependent => :destroy

  has_many :subscription_invoices
  has_many :subscription_addon_mappings,
    :class_name=> "Subscription::AddonMapping"
  has_many :addons,
    :class_name => "Subscription::Addon",
    :through => :subscription_addon_mappings,
    :source => :subscription_addon,
    :before_add => :cache_old_addons,
    :before_remove => :cache_old_addons,
    :foreign_key => :subscription_addon_id

  belongs_to :currency,
    :class_name => "Subscription::Currency",
    :foreign_key => :subscription_currency_id


  before_create :set_renewal_at, :enable_auto_collection
  before_save :update_amount, unless: :anonymous_account?

  before_update :cache_old_model, :cache_old_addons
  before_update :clear_loyalty_upgrade_banner, if: :plan_changed?
  before_update :create_omni_bundle, if: :omni_plan_conversion?
  before_update :mark_switch_annual_notification, if: :switch_annual_notification_eligible?

  after_update :add_to_crm, unless: [:anonymous_account?, :disable_freshsales_api_integration?]
  after_update :update_reseller_subscription, unless: :anonymous_account?
  after_update :set_redis_for_first_time_account_activation, if: :freshdesk_freshsales_bundle_enabled?

  after_commit :update_crm, on: :update, unless: :anonymous_account?
  after_commit :update_fb_subscription, :dkim_category_change, :update_ticket_activity_export, on: :update
  after_commit :clear_account_susbcription_cache
  after_commit :schedule_account_block, :update_status_in_freshid, on: :update, :if => [:moved_to_suspended?]
  after_commit :suspend_tenant,  on: :update, :if => :trial_to_suspended?
  after_commit :reactivate_account, :update_status_in_freshid, on: :update, :if => [:moved_from_suspended?]
  after_commit :update_sandbox_subscription, on: :update, if: :account_has_sandbox?
  after_commit :complete_onboarding, on: :update, if: :upgrade_from_trial?
  after_commit :launch_downgrade_policy, unless: :policy_applied_account?
  after_commit :trigger_switch_to_annual_notification_scheduler, on: :update, if: :trigger_switch_annual_notification?
  after_commit :enqueue_omni_account_creation_workers, if: [:omni_plan_conversion?, :enqueue_omni_account_creation?]

  attr_accessor :creditcard, :address, :billing_cycle, :subscription_term_start, :lock_old_addons
  attr_reader :response
  serialize :additional_info, Hash

  scope :paying_subscriptions, -> {
    where(["state = '#{ACTIVE}' AND amount > 0.00"]).
    includes(:currency)
  }

  scope :free_subscriptions, -> {
    where(["state IN ('#{ACTIVE}', '#{FREE}') AND amount = 0.00"])
  }

  scope :filter_with_currency, -> (currency) {
    where(subscription_currency_id: currency.id)
  }
  
  scope :filter_with_state, -> (state) {
    where(state: state)
  }

  delegate :contact_info, :admin_first_name, :admin_last_name, :admin_email, :admin_phone,
           :invoice_emails, :to => "account.account_configuration"
  delegate :name, :full_domain, :to => "account", :prefix => true

  delegate :name, :billing_site, :billing_api_key, :exchange_rate, :to => :currency, :prefix => true

  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :only_integer => true, :greater_than => 0
  # validates_numericality_of :amount, :greater_than_or_equal_to => 0
  # validate_on_create :card_storage
  validates_inclusion_of :state, :in => SUBSCRIPTION_TYPES
  # validates_numericality_of :amount, :if => :free?, :equal_to => 0.00, :message => I18n.t('not_eligible_for_free_plan')
  validates_numericality_of :agent_limit, :if => Proc.new { |a| (a.free? && a.non_new_sprout?) }, :less_than_or_equal_to => AGENTS_FOR_FREE_PLAN, :message => I18n.t('not_eligible_for_free_plan')

  NEW_SPROUT = [
    SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_jan_17],
    SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_jan_19],
    SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_jan_20]
  ].freeze

  NEW_BLOSSOM = [
    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_17],
    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_19],
    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_20]
  ].freeze

  def self.customer_count
   where(state: [ACTIVE, FREE]).count
  end

  def self.free_customers
   where(state: [ACTIVE, FREE], amount: 0.00).count
  end

  def self.customers_agent_count
    where(state: ACTIVE).sum(:agent_limit)
  end

  def self.customers_free_agent_count
    where(state: ACTIVE).sum(:free_agents)
  end

  def self.paid_agent_count
    where(['state = ? and amount > 0.00', ACTIVE]).sum('agent_limit - free_agents').to_i
  end

  #Total monthly revenue in USD
  def self.monthly_revenue
    paying_subscriptions().inject(0) { |sum, subscription| sum + subscription.cmrr }
  end

  #Monthly revenue in local currency
  def self.fetch_monthly_revenue(currency)
    subscriptions = paying_subscriptions.filter_with_currency(currency)
    subscriptions.inject(0) { |sum, subscription| sum + subscription.cmrr_in_local_currency }
  end

  def self.free_agent_count
    where(state: [ACTIVE, FREE]).sum('free_agents').to_i
  end

  def self.fetch_by_account_id(account_id)
    key = MemcacheKeys::ACCOUNT_SUBSCRIPTION % { :account_id => account_id }
    MemcacheKeys.fetch(key) { Subscription.find_by_account_id(account_id) }
  end

  def cmrr
    (usd_equivalent/renewal_period).to_f
  end

  def usd_equivalent
    (amount * currency_exchange_rate).to_f
  end

  def cmrr_in_local_currency
    (amount/renewal_period).to_f
  end


  # This hash is used for validating the subscription when a plan
  # is changed.  It includes both the validation rules and the error
  # message for each limit to be checked.
#  Limits = {
#    Proc.new {|account, plan| !plan.user_limit || plan.user_limit >= Account::Limits['user_limit'].call(account) } =>
#      'User limit for new plan would be exceeded.  Please delete some users and try again.'
#  }

  # Changes the subscription plan, and assigns various properties,
  # such as limits, etc., to the subscription from the assigned
  # plan.  When adding new limits that are specified in
  # SubscriptionPlan, don't forget to add those new fields to the
  # assignments in this method.
  def plan=(plan)
    self.renewal_period = billing_cycle unless billing_cycle.nil?
    self.subscription_plan = plan
    self.free_agents = plan.free_agents if free_agents.nil?
    self.day_pass_amount = plan.day_pass_amount
  end

  # The plan_id and plan_id= methods are convenience methods for the
  # administration interface.
  def plan_id
    subscription_plan_id
  end

  def plan_id=(a_plan_id)
    self.plan = SubscriptionPlan.find(a_plan_id) if a_plan_id.to_i != subscription_plan_id
  end

  def trial_days
    ((self.next_renewal_at.to_i - Time.now.to_i) / 86400).to_i
  end

  def no_of_days(from,to)
    ((from.to_i - to.to_i) / 86400).to_i
  end

  def amount_in_pennies
    (amount * 100).to_i
  end

  def paid_agents
    (agent_limit - free_agents)
  end

  def current?
    next_renewal_at >= Time.now
  end

  def suspended?
    state == 'suspended'
  end

  def active?
    state == 'active'
  end

  def trial?
    state == 'trial'
  end

  def free?
    state == 'free'
  end

  def moved_to_suspended?
    @old_subscription.state != SUSPENDED && self.state == SUSPENDED
  end

  def moved_from_suspended?
    @old_subscription.state == SUSPENDED && self.state != SUSPENDED
  end

  def non_new_sprout?
    !new_sprout?
  end

  def sprout?
    subscription_plan_from_cache.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]
  end

  def sprout_classic?
    subscription_plan_from_cache.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_classic]
  end

  def new_sprout?
    NEW_SPROUT.include?(subscription_plan_from_cache.name)
  end

  def new_blossom?
    NEW_BLOSSOM.include?(subscription_plan_from_cache.name)
  end

  def blossom?
    subscription_plan_from_cache.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom]
  end

  def blossom_classic?
    subscription_plan_from_cache.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_classic]
  end

  def subscription_plan_from_cache
    SubscriptionPlan.subscription_plans_from_cache.select { |s_plan| s_plan.id == self.plan_id }.first
  end

  def classic?
    subscription_plan.classic
  end

  def eligible_for_free_plan?
    (account.full_time_support_agents.count <= AGENTS_FOR_FREE_PLAN)
  end

  def convert_to_free
    self.state = 'free' if card_number.blank?
    self.agent_limit = subscription_plan.free_agents
    self.renewal_period = 1
    self.day_pass_amount = subscription_plan.day_pass_amount
    self.free_agents = subscription_plan.free_agents
    self.next_renewal_at = Time.now.advance(:months => 1)
  end

  def update_fb_subscription
    old_state = @old_subscription.state
    if (old_state != "suspended" && state == "suspended")
      facebook_callback = "cleanup"
    elsif (old_state == "suspended" && state != "suspended")
      facebook_callback =  "subscribe_realtime"
    end
    update_facebook_subscription(facebook_callback) if facebook_callback
  end

  def update_ticket_activity_export
    old_state = @old_subscription.state
    if (old_state != "suspended" && state == "suspended")
      ticket_activity_export = account.activity_export
      return if ticket_activity_export.nil? or !ticket_activity_export.active
      ticket_activity_export.active = false
      ticket_activity_export.save
    end
  end

  def offline_subscription?
    additional_info.key?(:auto_collection) ? !additional_info[:auto_collection] : Billing::Subscription.new.offline_subscription?(account_id)
  end

  def mark_auto_collection(auto_collection)
    additional_info = self.additional_info || {}
    additional_info[:auto_collection] = AUTO_COLLECTION[auto_collection]
    update(additional_info: additional_info)
  end

  def mark_switch_annual_notification
    additional_info = self.additional_info || {}
    additional_info[:annual_notification_triggered] = true
  end

  def applicable_addons(addons, plan)
    addons.to_a.collect{ |addon| addon if addon.allowed_in_plan?(plan) }.compact
  end

  def billing
    Billing::Subscription.new
  end

  def set_billing_params(currency)
    currency_object = Subscription::Currency.find_by_name(currency)
    self.currency = currency_object
  end

  def coupon
    result = billing.retrieve_subscription(account_id)
    result.subscription.coupon
  end

  def fetch_fdfs_discount_coupon
    if trial? && account.account_additional_settings.additional_settings[:onboarding_version] == SubscriptionConstants::FDFSONBOARDING && \
       created_at > DateTime.now.utc - 21.days
      SubscriptionConstants::FDFSBUNDLE
    end
  end

  def retrieve_addon_price(addon)
    response = billing.retrieve_addon(addon_mapping[addon])
    (response.addon.price)/100.0
  end

  def trial_expired?
    suspended? and card_number.blank? and subscription_payments.empty?
  end

  def paid_account?
    (state == 'active') and (subscription_payments.count > 0)
  end
  alias :is_paid_account :paid_account?

  def verify_agent_limit
    if !downgrade? && agent_limit && agent_limit < account.full_time_support_agents.count
      errors.add(:base, agents: I18n.t('subscription.error.agents_count', agents_count: account.full_time_support_agents.count))
    end
  end

  def verify_agent_field_limit
    if immediate_downgrade? && field_agent_limit && field_agent_limit < account.field_agents_count
      errors.add(:base, 'field technicians': I18n.t('subscription.error.field_agents_count', field_agents_count: account.field_agents_count))
    end
  end

  def verify_unlimited_multi_product
    if immediate_downgrade? && chk_multi_product
      errors.add(:base, products: I18n.t('subscription.error.products_count', products_count: account.products.count))
    end
  end

  def immediate_downgrade?
    !(account.launched?(:downgrade_policy) && active?)
  end

  def chk_multi_product
    account.has_feature?(:unlimited_multi_product) && !subscription_plan.unlimited_multi_product? && subscription_plan.multi_product? && account.products.count > AccountConstants::MULTI_PRODUCT_LIMIT
  end

  def non_free_agents
    non_free_agents =  (agent_limit || account.full_time_support_agents.count) - free_agents
    (non_free_agents > 0) ? non_free_agents : 0
  end

  def available_free_agents
    agents = agent_limit || account.full_time_support_agents.count
    if (free_agents >= agents)
      available_free_slots = (free_agents - agents).to_s + " available"
    else
      available_free_slots = free_agents
    end
    available_free_slots
  end

  def is_chat_plan?
    FRESHCHAT_PLANS.include?(subscription_plan_from_cache.name)
  end

  def set_next_renewal_at(billing_subscription)
    self.next_renewal_at = if (renewal_date = billing_subscription.current_term_end)
      Time.at(renewal_date).to_datetime.utc
    else
      Time.at(billing_subscription.trial_end).to_datetime.utc
    end
  end

  def set_billing_info(card)
    self.card_number = card.masked_number
    self.card_expiration = "%02d-%d" % [card.expiry_month, card.expiry_year]
    self.update_billing_address(card)
  end

  def fetch_billing_address(card_details)
    {
      billing_address: {
        first_name: card_details.first_name,
        last_name: card_details.last_name,
        line1: "#{card_details.billing_addr1} #{card_details.billing_addr2}",
        city: card_details.billing_city,
        state: card_details.billing_state,
        zip: card_details.billing_zip,
        country: card_details.billing_country
      }
    }
  end

  def clear_billing_info
    self.card_number = nil
    self.card_expiration = nil
    self.billing_id = nil
  end

  def paid_account?
    (state == 'active') and (subscription_payments.count > 0)
  end
  alias :is_paid_account :paid_account?

  def total_amount(addons, coupon_code)
    subscription_estimate(addons, coupon_code)
    self.amount = to_currency(response.estimate.sub_total)
    self.additional_info[:amount_with_tax] = to_currency(response.estimate.amount)
  end

  def discount_amount(addons, coupon_code)
    subscription_estimate(addons, coupon_code)
    @response.estimate.discounts ? to_currency(response.estimate.discounts.first.amount) : nil
  end

  def plan_name
    subscription_plan_from_cache.name
  end

  def non_sprout_plan?
    !(sprout? || sprout_classic? || new_sprout?)
  end

  def sprout_plan?
    !(non_sprout_plan?)
  end

  def trial_or_sprout_plan?
    state == 'trial' || sprout_plan?
  end


  def forum_available_plan?
    non_sprout_plan? && !new_blossom?
  end

  def renewal_in_two_days?
    (Time.zone.now + 2.days) >= next_renewal_at
  end

  def field_agents_display_count
    count = account.field_agents_count
    limit = field_agent_limit || 0
    count > limit ? count : limit
  end

  def amount_with_tax_safe_access
    self.additional_info[:amount_with_tax].presence || self.amount
  end

  def field_agent_limit
    self.additional_info.try(:[], :field_agent_limit)
  end

   def field_agent_limit=(value)
    self.additional_info ||= {}
    self.additional_info[:field_agent_limit] = value
  end

  def reset_field_agent_limit
    return if self.additional_info.try(:[], :field_agent_limit).nil?
    self.additional_info = self.additional_info.except(:field_agent_limit)
    Rails.logger.info "Resetting field agent limit:: Account:: #{self.account_id}"
    save
  end

  def freddy_sessions=(value)
    self.additional_info ||= {}
    self.additional_info[:freddy_sessions] = value
  end

  def freddy_sessions
    self.additional_info.try(:[], :freddy_sessions).to_i
  end

  def freddy_session_packs
    self.additional_info.try(:[], :freddy_session_packs).to_i
  end

  def freddy_session_packs=(session_packs)
    self.additional_info ||= {}
    self.additional_info[:freddy_session_packs] = session_packs
  end

  def freddy_billing_model
    self.additional_info.try(:[], :freddy_billing_model)
  end

  def remove_addon(addon_name)
    attempt = 0
    no_of_retries = 3
    begin
      if addons.any? { |addon| addon.name == addon_name }
        new_addons = addons.reject { |addon| addon.name == addon_name }
        Billing::Subscription.new.update_subscription(self, prorate_on_addons_removal?, new_addons) unless SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.key?(addon_name) && field_agent_limit.to_i.zero?
        self.addons = new_addons
        save
      end
    rescue StandardError => e
      attempt += 1
      retry if attempt < no_of_retries
      Rails.logger.error "Exception while removing addon:: #{addon_name} Account:: #{Account.current.id} #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Exception while removing addon:: #{addon_name}, Account:: #{Account.current.id}, Message: #{e.message}")
      raise e
    end
  end


  def update_subscription(params)
    return false unless save_subscription(params)

    update_features if plan_changed? && !subscription_downgrade?
    add_to_subscription_events
  end

  def fetch_immediate_estimate
    @fetch_immediate_estimate ||= begin
      updated_addons = applicable_addons(present_subscription.addons, subscription_plan)
      Billing::Subscription.new.fetch_estimate_info(self, updated_addons)
    end
  end

  def fetch_subscription_estimate(coupon)
    updated_addons = applicable_addons(present_subscription.addons, subscription_plan)
    applicable_coupon = verify_coupon(coupon)
    response = subscription_estimate(updated_addons, applicable_coupon)
    self.amount = to_currency(response.estimate.sub_total)
    self.additional_info[:amount_with_tax] = to_currency(response.estimate.amount)
    response
  end

  def fetch_update_payment_site
    result = Billing::Subscription.new.update_payment_method(account.id)
    hosted_page = result.hosted_page
    {
      url: hosted_page.url,
      site: currency_billing_site
    }
  end

  def reseller_paid_account?
    account.reseller_paid_account?
  end

  def subscription_downgrade?
    @subscription_downgrade ||= downgrade?
  end

  def downgrade?
    (account.launched?(:downgrade_policy) && active? &&
      !present_subscription.subscription_plan.amount.zero? &&
      present_subscription.agent_limit > present_subscription.free_agents &&
      (plan_downgrade? || omni_plan_dowgrade? || term_reduction? || agent_limit_reduction? || fsm_downgrade? || freddy_downgrade?))
  end

  def plan_downgrade?
    cost_per_agent < present_subscription.cost_per_agent if subscription_plan_id != present_subscription.subscription_plan_id
  end

  def omni_plan_dowgrade?
    (present_subscription.subscription_plan.omni_plan? || present_subscription.subscription_plan.free_omni_channel_plan?) && subscription_plan.basic_variant?
  end

  def term_reduction?
    renewal_period < present_subscription.renewal_period
  end

  def agent_limit_reduction?
    agent_limit < present_subscription.agent_limit
  end

  def fsm_downgrade?
    present_subscription.field_agent_limit.to_i > 0 && (field_agent_limit.blank? ||
      present_subscription.field_agent_limit > field_agent_limit)
  end

  def freddy_downgrade?
    (present_subscription.freddy_sessions > 0 && (freddy_sessions.blank? ||
      present_subscription.freddy_sessions > freddy_sessions)) ||
      (present_subscription.freddy_session_packs > 0 && (freddy_session_packs.blank? ||
        present_subscription.freddy_session_packs > freddy_session_packs)) || compare_addon_and_plan_sessions
  end

  def compare_addon_and_plan_sessions
    (present_subscription.freddy_sessions - (present_subscription.freddy_session_packs * SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_session_packs])) / present_subscription.renewal_period >
      (freddy_sessions - (freddy_session_packs * SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_session_packs])) / renewal_period
  end

  def cost_per_agent(plan_period = renewal_period)
    plan = retrieve_plan_from_cache(subscription_plan, plan_period)
    (plan.plan.price / plan.plan.period) / 100
  end

  def present_subscription
    @present_subscription ||= cache_old_model
  end

  def paying_account?
    active? && amount > 0
  end

  def switch_currency(currency)
    # cancel subscription in old site and clone the subscription in the new site
    data = fetch_migration_data
    billing.cancel_subscription(account)
    set_billing_params(currency)
    clone_subscription(data)
    save!
  end

  def add_card_to_billing
    customer_details = billing.retrieve_subscription(account_id)
    set_billing_info(customer_details.card)
    save!
  rescue StandardError => e
    Rails.logger.info "Exception occurred while updating card details #{e.inspect}"
    NewRelic::Agent.notice_error(e, description: "Exception while adding card details, Account:: #{Account.current.id}, Message: #{e.message}")
    false
  end

  def activate_subscription
    customer_details = billing.retrieve_subscription(account_id)
    billing_address = fetch_billing_address(customer_details.card)
    result = billing.activate_subscription(self, billing_address)
    self.state = ACTIVE
    set_next_renewal_at(result.subscription)
    save!
  rescue StandardError => e
    Rails.logger.info "Exception occurred while activating subscription #{e.inspect}"
    NewRelic::Agent.notice_error(e, description: "Exception while activating subscription, Account:: #{Account.current.id}, Message: #{e.message}")
    false
  end

  def percentage_difference
    return if renewal_period == ANNUAL_PERIOD || annual_cost_per_agent.zero?

    current_cycle_cost = cost_per_agent
    annual_cycle_cost = annual_cost_per_agent
    ((((current_cycle_cost - annual_cycle_cost) / annual_cycle_cost.to_f) * 100) / 5).floor * 5
  end

  def losing_features(to_plan)
    new_plan = SubscriptionPlan.subscription_plans_from_cache.find { |plan| plan.id == to_plan }
    features_lost = account.features_list - PLANS[:subscription_plans][new_plan.canon_name][:features]
    features_lost
  end

  def update_subscription_on_signup(plan_name)
    self.plan = SubscriptionPlan.current.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[plan_name])
    self.state = TRIAL
    convert_to_free if new_sprout?
    save!
    update_features
  end

  protected

    def annual_cost_per_agent
      @annual_cost_per_agent ||= cost_per_agent(ANNUAL_PERIOD)
    end

    def set_renewal_at
      return if self.subscription_plan.nil? || self.next_renewal_at
      self.next_renewal_at = Time.now.advance(:days => TRIAL_DAYS)
    end

    def update_facebook_subscription(facebook_method_name)
      account.facebook_pages.each do |fb_page|
        fb_page.safe_send(facebook_method_name)
      end
    end

    # If the discount is changed, set the amount to the discounted
    # plan amount with the new discount.
    def update_amount
      if self.amount.blank? || Rails.env.test?
        self.amount = subscription_plan.amount
      else
        response = Billing::Subscription.new.calculate_update_subscription_estimate(self, addons)
        self.amount = to_currency(response.estimate.sub_total)
        self.additional_info.merge!(amount_with_tax: to_currency(response.estimate.amount))
      end
    rescue StandardError => e
      Rails.logger.error "Exception occurred while updating amount #{e.message}"
    end

    def subscription_estimate(addons, coupon_code)
      unless active?
        @response ||= Billing::Subscription.new.calculate_estimate(self, addons, coupon_code)
      else
        @response ||= Billing::Subscription.new.calculate_update_subscription_estimate(self, addons)
      end
    end

    def cache_old_model
      @old_subscription = Subscription.find id
    end

    def cache_old_addons(*)
      @old_addons = addons.dup unless self.lock_old_addons
      self.lock_old_addons = true
    end

    def validate_errors_on_update
      verify_agent_limit || verify_agent_field_limit || verify_unlimited_multi_product
      validation_errors = errors[:base]
      return false if validation_errors.blank?

      errors[:base] = construct_subscription_error_msgs(validation_errors)
      true
    end

    def finished_trial?
      next_renewal_at < Time.zone.now
    end

    def free_plan?
      subscription_plan_from_cache.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:free]
    end

    def update_billing_address(card)
      billing_address = self.billing_address
      return billing_address.update_attributes(address(card)) if billing_address

      billing_address = self.build_billing_address(address(card))
      billing_address.account = account
      billing_address.save
    end

    def address(card)
      ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = card.safe_send(v); h }
    end

    def config_from_file(file)
      YAML.load_file(File.join(Rails.root, 'config', file))[Rails.env].symbolize_keys
    end

    def set_free_plan_agnt_limit
      self.agent_limit = AppConfig['free_plan_agts'] if free_plan?
    end

  private

    def enable_auto_collection
      self.additional_info ||= {}
      self.additional_info[:auto_collection] = true
    end

    # Clear the feature so that loyalty upgrade is not shown to the customers.
    def clear_loyalty_upgrade_banner
      unless @old_subscription.additional_info[:feature_gain].nil? && @old_subscription.additional_info[:discount].nil?
        additional_info[:feature_gain] = nil
        additional_info[:discount] = nil
      end
    end

    def fetch_migration_data
      data = billing.retrieve_subscription(account_id)
      migration_data = {
        coupon: data.subscription.coupon
      }
      migration_data[:trial_end] = if suspended?
                                     1.hour.from_now.to_i
                                   elsif free?
                                     0
                                   else
                                     data.subscription.trial_end
                                   end
      migration_data
    end

    def clone_subscription(data)
      if billing.subscription_exists?(account_id)
        billing.reactivate_subscription(self, data)
      else
        billing.create_subscription(account, data)
      end
    end

    def save_subscription(params)
      self.renewal_period = params[:renewal_period] if params[:renewal_period].present?
      self.agent_limit = params[:agent_seats] if params[:agent_seats]
      # If in future when we get the addon params in this subscription api, we have to handle the addons
      updated_addons = update_billing_based_addon(self.addons, self.renewal_period) || self.addons
      if params[:plan_id].present? && params[:plan_id] != plan_id
        new_plan = SubscriptionPlan.current.find_by_id(params[:plan_id])
        self.plan = new_plan
        updated_addons = applicable_addons(addons, new_plan)
        self.free_agents = new_plan.free_agents
        convert_to_free if new_sprout?
      end
      self.freddy_sessions = calculate_freddy_session(updated_addons, self, self.subscription_plan.name.parameterize.underscore.to_sym, self.renewal_period) if account.launched?(:freddy_subscription)
      return false if validate_errors_on_update

      applicable_coupon = verify_coupon(present_subscription.coupon)
      if subscription_downgrade?
        total_amount(updated_addons, applicable_coupon)
        response = billing.update_subscription(self, false, updated_addons, applicable_coupon, true)
        construct_subscription_request(updated_addons, response.subscription.current_term_end).save!
      else
        @chargebee_update_response = billing.update_subscription(self, prorate?(applicable_coupon), updated_addons)
        subscription_request.destroy if subscription_request.present?
        billing.add_discount(account, applicable_coupon) if @chargebee_update_response.subscription.coupon != applicable_coupon
        set_next_renewal_at(@chargebee_update_response.subscription)
        self.addons = updated_addons
        save
      end
    rescue ChargeBee::InvalidRequestError => e
      Rails.logger.error("Exception on updating the subscription account_id: \
        #{account_id}, message: #{e.json_obj[:message]}")
      errors.add(e.error_code, e.json_obj[:message])
      false
    end

    def construct_subscription_request(updated_addons, next_renewal_at)
      is_freddy_downgrade = freddy_downgrade?
      downgrade_request = subscription_request.nil? ? build_subscription_request : subscription_request
      downgrade_request.plan_id = plan_id
      downgrade_request.renewal_period = renewal_period
      downgrade_request.agent_limit = agent_limit
      downgrade_request.fsm_field_agents = (updated_addons.map(&:name) & SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.keys).present? && field_agent_limit.present? ? field_agent_limit : nil
      downgrade_request.next_renewal_at = Time.at(next_renewal_at).to_datetime.utc
      downgrade_request.from_plan = present_subscription.subscription_plan_from_cache
      downgrade_request.fsm_downgrade = present_subscription.field_agent_limit.present? && field_agent_limit.blank?
      downgrade_request.additional_info = downgrade_request.additional_info || {}
      downgrade_request.additional_info[:freddy_downgrade] = is_freddy_downgrade
      downgrade_request.additional_info[:freddy_session_packs] = freddy_session_packs
      downgrade_request.additional_info[:freddy_self_service_requested] = is_addon_enabled(updated_addons, Subscription::Addon::FREDDY_SELF_SERVICE_ADDON) && !is_addon_enabled(updated_addons, Subscription::Addon::FREDDY_ULTIMATE_ADDON)
      downgrade_request.additional_info[:freddy_ultimate_requested] = is_addon_enabled(updated_addons, Subscription::Addon::FREDDY_ULTIMATE_ADDON)
      downgrade_request
    end

    def verify_coupon(old_coupon)
      old_coupon.present? && billing.coupon_applicable?(self, old_coupon) ? old_coupon : nil
    end

    # No proration(credit) in monthly downgrades
    def prorate?(applicable_coupon)
      !(present_subscription.active? && (total_amount(addons, applicable_coupon) < present_subscription.amount) &&
        NO_PRORATION_PERIOD_CYCLES.include?(present_subscription.renewal_period))
    end

    def set_redis_for_first_time_account_activation
      if @old_subscription.trial? && active? && subscription_payments.count.zero?
        account.first_time_account_purchased
      end
    end

    def freshdesk_freshsales_bundle_enabled?
      account.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle]
    end

    #CRM
    def free_customer?
      (amount == 0 and active? ) || free?
    end

    def free_plan_selected?
      state_changed? and free?
    end

    def add_to_crm
      CRMApp::Freshsales::TrackSubscription.perform_at(5.minutes.from_now, {
        account_id: account_id,
        old_subscription: @old_subscription.attributes,
        old_cmrr: @old_subscription.cmrr,
        subscription: self.attributes,
        cmrr: self.cmrr,
        payments_count: self.subscription_payments.count
      }) if changes.any?
    end

    def update_crm
      if freshmarketer_fields_changed? and (Rails.env.staging? or Rails.env.production?)
        Subscriptions::UpdateLeadToFreshmarketer.perform_async(event: ThirdCRM::EVENTS[:subscription])
      end
    end

    def dkim_category_change
      if self.account.dkim_enabled? and subscription_state_changed?
        set_others_redis_lpush(DKIM_CATEGORY_KEY, self.account_id)
      end
    end

    def update_reseller_subscription
      if state_changed? or (active? and amount_changed?) or subscription_currency_id_changed? or next_renewal_at_changed?
        Subscription::UpdatePartnersSubscription.perform_async({ :account_id => account_id,
          :event_type => :subscription_updated })
      end
    end

    def addon_mapping
      {
        :day_pass => subscription_plan.canon_name,
        :field_service_management => (subscription_plan.classic ? :field_service_management : :field_service_management_20)
      }
    end

    def to_currency(amount)
      (amount/100.0).round.to_f
    end

    def clear_account_susbcription_cache
      key = MemcacheKeys::ACCOUNT_SUBSCRIPTION % { :account_id => self.account_id }
      MemcacheKeys.delete_from_cache key
    end

    def suspend_tenant
      SearchService::Client.new(self.account_id).tenant_suspend
    end

    def reactivate_account
      SearchService::Client.new(self.account_id).tenant_reactivate
    end

    def freshmarketer_fields_changed?
      FRESHMARKETER_FILEDS.each do |field|
        return true if self.safe_send(field) != @old_subscription.safe_send(field)
      end
      return nil
    end

    def subscription_state_changed?
      @old_subscription.state.eql?(TRIAL) and self.state.eql?(ACTIVE)
    end

    def trial_to_suspended?
      @old_subscription.state.eql?(TRIAL) && self.state.eql?(SUSPENDED)
    end

    def active_to_suspended?
      (@old_subscription.state.eql?(FREE) || @old_subscription.state.eql?(ACTIVE)) && self.state.eql?(SUSPENDED)
    end

    def schedule_account_block
      if active_to_suspended?
        key = ACTIVE_SUSPENDED % {:account_id => self.account.id}
        set_others_redis_key(key, true, Account::BLOCK_GRACE_PERIOD)
        Rails.logger.debug("Added trial suspended redis key for account_id: #{self.account.id}")
      end
      #BlockAccount.perform_in(Account::BLOCK_GRACE_PERIOD.from_now, {:account_id => self.account.id})
    end

    def prorate_on_addons_removal?
      NO_PRORATION_PERIOD_CYCLES.exclude?(self.renewal_period)
    end

    def update_status_in_freshid
      account.update_account_details_in_freshid(true)
    end

    def freshid_status
      status = (state == SUSPENDED) ? :inactive : :active
    end

    def anonymous_account?
      account.anonymous_account?
    end

    def omni_plan_conversion?
      account.launched?(:explore_omnichannel_feature) && @chargebee_update_response.present? && !@old_subscription.subscription_plan.omni_plan? && subscription_plan.omni_bundle_plan? && !account.not_eligible_for_omni_conversion?
    end

    def enqueue_omni_account_creation?
      account.freshchat_account.blank? && account.freshcaller_account.blank?
    end

    def create_omni_bundle
      bundle = account.create_organisation_bundle(OmniChannelBundleConfig['bundle_type_identifier'])
      if bundle.present? && bundle[:bundle].present?
        bundle_id = bundle[:bundle][:id]
        bundle_name = bundle[:bundle][:name]
        account.update_bundle_id(bundle_id, bundle_name)
      end
    end

    def enqueue_omni_account_creation_workers
      if account.omni_bundle_id.present?
        worker_args = {
          chargebee_response: @chargebee_update_response
        }
        OmniChannelUpgrade::FreshcallerAccount.perform_async(worker_args)
        OmniChannelUpgrade::FreshchatAccount.perform_async(worker_args)
      end
    end

    def disable_freshsales_api_integration?
      account.disable_freshsales_api_integration?
    end

    def policy_applied_account?
      account.launched? :downgrade_policy
    end

    def plan_changed?
      @old_subscription.subscription_plan_id != subscription_plan_id
    end

    def switch_annual_notification_eligible?
      !@old_subscription.additional_info[:annual_notification_triggered] && renewal_period != SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] && \
        amount > 0 && first_time_paid_non_annual_plan? && !offline_subscription? && !reseller_paid_account?
    end

    def first_time_paid_non_annual_plan?
      active? && subscription_payments.reject { |payment| payment.meta_info.present? && payment.meta_info[:renewal_period] == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] }.count.zero?
    end

    def trigger_switch_annual_notification?
      !@old_subscription.additional_info[:annual_notification_triggered] && additional_info[:annual_notification_triggered]
    end

    def update_features
      SAAS::SubscriptionEventActions.new(account, @old_subscription, @old_addons).change_plan
      account.active_trial.update_result!(@old_subscription, self) if account.active_trial.present?
    end

    def add_to_subscription_events
      args = { account_id: account_id,
               subscription_id: id,
               subscription_hash: subscription_info(@old_subscription) }
      args.merge!(current_user_id: User.current.id) if User.current.present?
      if account.launched?(:downgrade_policy)
        args[:requested_subscription_hash] = subscription_info(self)
        args[:requested_subscription_hash][:is_downgrade] = downgrade?
        args[:requested_subscription_hash][:field_agent_limit] = subscription_request.present? ? subscription_request.fsm_field_agents : nil
        args[:subscription_hash][:subscription_term_start] = subscription_term_start
        args[:subscription_hash][:field_agent_limit] = @old_subscription.additional_info[:field_agent_limit]
      end
      Subscriptions::SubscriptionAddEvents.perform_async(args)
    end

    def subscription_info(subscription)
      subscription_attributes = SUBSCRIPTION_ATTRIBUTES.each_with_object({}) do |(k, v), hash|
        hash[k] = subscription.safe_send(v)
      end
      subscription_attributes.merge!(next_renewal_at: subscription.next_renewal_at.to_s(:db))
    end

    def update_sandbox_subscription
      sandbox_account_id = account.sandbox_job.sandbox_account_id
      sandbox_state = moved_to_suspended? ? SUSPENDED : TRIAL
      ::Admin::Sandbox::UpdateSubscriptionWorker.perform_async(account_id: account_id, sandbox_account_id: sandbox_account_id, state: sandbox_state)
    end

    def complete_onboarding
      complete_account_onboarding
    end

    def upgrade_from_trial?
      (@old_subscription.state.eql?(TRIAL) || @old_subscription.state.eql?(SUSPENDED)) && (state.eql?(ACTIVE) || state.eql?(FREE)) && account.onboarding_pending?
    end

    def account_has_sandbox?
      account.production_with_sandbox? && (moved_to_suspended? || moved_from_suspended?)
    end

    def launch_downgrade_policy
      renewal_period_change = previous_changes['renewal_period']
      account.launch(:downgrade_policy) if renewal_period_change.present? && renewal_period_change[0] != renewal_period_change[1]
    end
 end
