class Subscription < ActiveRecord::Base
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Cache::Memcache::SubscriptionPlan
  
  self.primary_key = :id
  SUBSCRIPTION_TYPES = ["active", "trial", "free", "suspended"]
  
  AGENTS_FOR_FREE_PLAN = 3

  TRIAL_DAYS = 21

  SUBSCRIPTION_ATTRIBUTES = { :account_id => :account_id, :amount => :amount, :state => :state,
                              :subscription_plan_id => :subscription_plan_id, :agent_limit => :agent_limit,
                              :free_agents => :free_agents, :renewal_period => :renewal_period, 
                              :subscription_discount_id => :subscription_discount_id, 
                              :usd_equivalent => :usd_equivalent }

  ADDRESS_INFO = { :first_name => :first_name, :last_name => :last_name, :address1 => :billing_addr1,
                  :address2 => :billing_addr2, :city => :billing_city, :state => :billing_state,
                  :country => :billing_country, :zip => :billing_zip  }

  FRESHCHAT_PLANS = [ SubscriptionPlan::SUBSCRIPTION_PLANS[:garden], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_classic],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_classic], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:premium],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_jan_17], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_17],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_17],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_omni_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_omni_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_19]].freeze

  AUTOPILOT_FILEDS = ["state", "next_renewal_at", "renewal_period", "amount", "subscription_plan_id", "agent_limit"]

  FRESHCALLER_PLAN_MAPPING = {
    sprout_jan_19: 'sprout',
    blossom_jan_19: 'sprout',
    garden_jan_19: 'blossom',
    garden_omni_jan_19: 'blossom',
    estate_jan_19: 'garden',
    estate_omni_jan_19: 'garden',
    forest_jan_19: 'standard'
  }.freeze

  FRESHCHAT_PLAN_MAPPING = {
      sprout_jan_19: '1101',
      blossom_jan_19: '1101',
      garden_jan_19: '1201',
      garden_omni_jan_19: '1201',
      estate_jan_19: '1301',
      estate_omni_jan_19: '1301',
      forest_jan_19: '1401'
  }.freeze

  ACTIVE = "active"
  TRIAL = "trial"
  FREE = "free"
  SUSPENDED = "suspended"

  NO_PRORATION_PERIOD_CYCLES = [SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]].freeze

  concerned_with :presenter

  publishable on: [:update]
  
  belongs_to :account
  belongs_to :subscription_plan
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
    :foreign_key => :subscription_addon_id

  belongs_to :currency, 
    :class_name => "Subscription::Currency", 
    :foreign_key => :subscription_currency_id


  before_create :set_renewal_at
  before_save :update_amount, unless: :anonymous_account?

  before_update :cache_old_model
  after_update :add_to_crm, :update_reseller_subscription, unless: :anonymous_account?
  after_commit :update_crm, on: :update, unless: :anonymous_account?
  after_commit :update_social_subscription, :add_free_freshfone_credit, :dkim_category_change, :update_ticket_activity_export, on: :update
  after_commit :clear_account_susbcription_cache
  after_commit :schedule_account_block, :update_status_in_freshid, on: :update, :if => [:moved_to_suspended?]
  after_commit :suspend_tenant,  on: :update, :if => :trial_to_suspended?
  after_commit :reactivate_account, :update_status_in_freshid, on: :update, :if => [:moved_from_suspended?]
  after_commit :update_sandbox_subscription, on: :update, if: :account_has_sandbox?

  attr_accessor :creditcard, :address, :billing_cycle
  attr_reader :response
  serialize :additional_info, Hash

  scope :paying_subscriptions, { 
    :conditions => ["state = '#{ACTIVE}' AND amount > 0.00"],
    :include => "currency" }
  
  scope :free_subscriptions, { 
    :conditions => ["state IN ('#{ACTIVE}', '#{FREE}') AND amount = 0.00"] }
  
  scope :filter_with_currency, lambda { |currency| {    
    :conditions => { :subscription_currency_id => currency.id }
  }}
  
  scope :filter_with_state, lambda { |state| {
    :conditions => { :state => state }
  }}


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
    SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_jan_19]
  ].freeze

  NEW_BLOSSOM = [
    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_17],
    SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_19]
  ].freeze

  def self.customer_count
   count(:conditions => [ " state IN ('active','free') "])
  end
 
  def self.free_customers
   count(:conditions => {:state => ['active','free'],:amount => 0.00})
  end

  def self.customers_agent_count
    sum(:agent_limit, :conditions => { :state => 'active'})
  end
  
  def self.customers_free_agent_count
    sum(:free_agents, :conditions => { :state => ['active']})
  end

  def self.paid_agent_count
    sum('agent_limit - free_agents', :conditions => [ " state = 'active' and amount > 0.00"]).to_i
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
    sum('free_agents', :conditions => [ "state in ('#{ACTIVE}', '#{FREE}')"]).to_i
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
    subscription_plans_from_cache.select {|s_plan| s_plan.id == self.plan_id}.first
  end

  def classic?
    return SubscriptionPlan::JAN_2019_PLAN_NAMES.exclude?(subscription_plan.name) if account.force_2019_plan?
    subscription_plan.classic 
  end

  def eligible_for_free_plan?
    (account.full_time_support_agents.count <= AGENTS_FOR_FREE_PLAN)
  end

  def convert_to_free
    self.state = FREE if card_number.blank?
    self.agent_limit = subscription_plan.free_agents
    self.renewal_period = 1
    self.day_pass_amount = subscription_plan.day_pass_amount
    self.free_agents = subscription_plan.free_agents
    self.next_renewal_at = Time.now.advance(:months => 1)
  end

  def update_social_subscription
    old_state = @old_subscription.state
    if (old_state != "suspended" && state == "suspended")
      facebook_callback = "cleanup"
      twitter_callback = "cleanup"
    elsif (old_state == "suspended" && state != "suspended")
      facebook_callback =  "subscribe_realtime"
      twitter_callback = "build_default_streams"
    end
    update_gnip_subscription(twitter_callback) if twitter_callback
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
    Billing::Subscription.new.offline_subscription?(account_id)
  end

  def applicable_addons(addons, plan)
    addons.to_a.collect{ |addon| addon if addon.allowed_in_plan?(plan) }.compact
  end

  def add_free_freshfone_credit
    # if(@old_subscription.trial? and self.paying_account?)
    #   if account.freshfone_credit.blank?
    #     account.create_freshfone_credit(:available_credit => 5)
    #     account.freshfone_payments.create(:status_message => "promotional", 
    #                                       :purchased_credit => 5, :status => true)
    #   end
    # end
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


  def chk_change_agents 
    if(agent_limit && agent_limit < account.full_time_support_agents.count)
     errors.add(:base,I18n.t("subscription.error.lesser_agents", {:agent_count => account.full_time_support_agents.count}))
     Agent::SUPPORT_AGENT
    end  
  end

  def chk_change_field_agents
    if field_agent_limit && field_agent_limit < account.field_agents_count
      errors.add(:base, I18n.t('subscription.error.lesser_field_agents', agent_count: account.field_agents_count))
      Agent::FIELD_AGENT
    end
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

  def field_agent_limit
    self.additional_info.try(:[], :field_agent_limit)
  end

   def field_agent_limit=(value)
    self.additional_info ||= {}
    self.additional_info[:field_agent_limit] = value 
  end

  def amount_with_tax_safe_access
    self.additional_info[:amount_with_tax].presence || self.amount
  end

  def field_agents_display_count
    count = account.field_agents_count
    limit = field_agent_limit || 0
    count > limit ? count : limit
  end
  
  def reset_field_agent_limit
    return if self.additional_info.try(:[], :field_agent_limit).nil?
    self.additional_info = self.additional_info.except(:field_agent_limit)
    Rails.logger.info "Resetting field agent limit:: Account:: #{self.account_id}"
    save
  end

  def remove_addon(addon_name)
    attempt = 0
    no_of_retries = 3
    begin
      if addons.any? { |addon| addon.name == addon_name }
        new_addons = addons.reject { |addon| addon.name == addon_name }
        Billing::Subscription.new.update_subscription(self, prorate_on_addons_removal?, new_addons)
        self.addons = new_addons
        save
      end
    rescue StandardError => e
      attempt += 1
      retry if attempt < no_of_retries
      Rails.logger.error "Exception while removing addon:: #{addon_name} Account:: #{Account.current.id} #{e.message} \n #{e.body}"
      NewRelic::Agent.notice_error(e, description: "Exception while removing addon:: #{addon_name}, Account:: #{Account.current.id}, Message: #{e.message}")
      raise e
    end
  end

  protected
  
    def set_renewal_at
      return if self.subscription_plan.nil? || self.next_renewal_at
      self.next_renewal_at = Time.now.advance(:days => TRIAL_DAYS)
    end

    def update_gnip_subscription(twitter_method_name)
      account.twitter_handles.each do |twt_handle|
        twt_handle.safe_send(twitter_method_name)
      end
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
    
    def validate_on_update
      chk_change_agents unless trial?
      chk_change_field_agents if account.addon_based_billing_enabled? && account.field_service_management_enabled?
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

    def paying_account?
      state == 'active' and amount > 0
    end
   
   
  private

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
      if autopilot_fields_changed? and (Rails.env.staging? or Rails.env.production?)
        Subscriptions::UpdateLeadToAutopilot.perform_async(event: ThirdCRM::EVENTS[:subscription])
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
        :freshfone => :freshfonecredits,
        :field_service_management => :field_service_management
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

    def autopilot_fields_changed?
      AUTOPILOT_FILEDS.each do |field|
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

    def update_sandbox_subscription
      sandbox_account_id = account.sandbox_job.sandbox_account_id
      sandbox_state = moved_to_suspended? ? SUSPENDED : TRIAL
      ::Admin::Sandbox::UpdateSubscriptionWorker.perform_async(account_id: account_id, sandbox_account_id: sandbox_account_id, state: sandbox_state)
    end

    def account_has_sandbox?
      account.production_with_sandbox? && (moved_to_suspended? || moved_from_suspended?)
    end
 end
