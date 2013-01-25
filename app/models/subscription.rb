class Subscription < ActiveRecord::Base
  
  PRO_RATA_MIN_CHARGE = 4.00
  
  SUBSCRIPTION_TYPES = ["active","trial","free"]
  
  AGENTS_FOR_FREE_PLAN = 3

  NO_PRORATION_PERIOD_CYCLES = [1, 3]
  
  ACTIVE = "active"
  TRIAL = "trial"
  FREE = "free"
  
  belongs_to :account
  belongs_to :subscription_plan
  has_many :subscription_payments
  belongs_to :discount, :class_name => 'SubscriptionDiscount', :foreign_key => 'subscription_discount_id'
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  
  has_one :billing_address,:class_name => 'Address',:as => :addressable,:dependent => :destroy
  
  before_create :set_renewal_at
  before_update :cache_old_model, :charge_plan_change_mis
  before_update :set_discount_expiry, :if => :subscription_discount_id_changed?
    
  
  before_destroy :destroy_gateway_record
  before_validation :update_amount
  after_update :update_features,:send_invoice
  after_update :add_to_crm, :if => :free_customer?
  
  after_update :update_billing, :if => :active?
  after_update :add_card_to_billing, :if => :card_number_changed?
  after_update :activate_paid_customer_in_billing, :if => :card_number_changed?
  after_update :activate_free_customer_in_billing, :if => :free_plan_selected?

  attr_accessor :creditcard, :address, :billing_cycle
  attr_reader :response
  
  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :only_integer => true, :greater_than => 0
  validates_numericality_of :amount, :greater_than_or_equal_to => 0
  validate_on_create :card_storage
  validates_inclusion_of :state, :in => SUBSCRIPTION_TYPES
  validates_numericality_of :amount, :if => :free?, :equal_to => 0.00, :message => I18n.t('not_eligible_for_free_plan')
  validates_numericality_of :agent_limit, :if => :free?, :less_than_or_equal_to => AGENTS_FOR_FREE_PLAN, :message => I18n.t('not_eligible_for_free_plan')

  def self.customer_count
   count(:conditions => [ " state != 'trial' and next_renewal_at > '#{(Time.zone.now.ago 5.days).to_s(:db)}'"])
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
    sum('agent_limit - free_agents', :conditions => [ " state = 'active' and amount > 0.00 and next_renewal_at > '#{(Time.zone.now.ago 5.days).to_s(:db)}'"]).to_i
  end
 
  def self.monthly_revenue
    sum('amount/renewal_period', :conditions => [ " state = 'active' and amount > 0.00 and next_renewal_at > '#{(Time.zone.now.ago 5.days).to_s(:db)}'"]).to_f
  end

  def set_discount_expiry
    self.discount_expires_at = discount.calculate_discount_expiry if discount
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
    if plan.amount > 0
      # Discount the plan with the existing discount (if any)
      # if the plan doesn't already have a better discount
      plan.discount = discount if discount && discount > plan.discount
      # If the assigned plan has a better discount, though, then
      # assign the discount to the subscription so it will stick
      # through future plan changes
      self.discount = plan.discount if plan.discount && plan.discount > discount
    
    end
    
    self.renewal_period = billing_cycle unless billing_cycle.nil?
    self.subscription_plan = plan
    self.free_agents = plan.free_agents if free_agents.nil?
    self.day_pass_amount = plan.day_pass_amount
  end

  def subscription_discount=(discount)
    subscription_plan.discount = discount
    if discount and discount.can_be_applied_to?(subscription_plan) and discount.has_free_agents?
      self.free_agents = discount.free_agents
    else
      self.free_agents = subscription_plan.free_agents
    end
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
  
  def store_card(creditcard, gw_options = {})
    # Clear out payment info if switching to CC from PayPal
    @charge_now = gw_options[:charge_now]
    @response = if billing_id.blank?
      gateway.store(creditcard, gw_options)
    else
      gateway.update(billing_id, creditcard, gw_options)
    end
    if @response.success?
      self.card_number = creditcard.display_number
      self.card_expiration = "%02d-%d" % [creditcard.expiry_date.month, creditcard.expiry_date.year]
      update_billing_address(gw_options[:billing_address])
      set_billing
    else
      errors.add_to_base(@response.message)
      false
    end
  end
  
  # Charge the card on file the amount stored for the subscription
  # record.  This is called by the daily_mailer script for each 
  # subscription that is due to be charged.  A SubscriptionPayment
  # record is created, and the subscription's next renewal date is 
  # set forward when the charge is successful.
  # 
  # If this subscription is paid via paypal, check to see if paypal
  # made the charge and set the billing date into the future.
  def charge
    if amount == 0 || (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
      begin
        update_attributes(:next_renewal_at => self.next_renewal_at.advance(:months => self.renewal_period), :state => 'active')
        create_payment(amount) unless amount == 0
       rescue Exception => err
         SubscriptionNotifier.deliver_sub_error({:error_msg => err.message, :full_domain => account.full_domain, :custom_message => "Charge failed" })
       end
       true
      else
        errors.add_to_base(@response.message)
        false
      end
  end
  
  
  # Charge the card on file any amount you want.  Pass in a dollar
  # amount (1.00 to charge $1).  A SubscriptionPayment record will
  # be created, but the subscription itself is not modified.
  def misc_charge(amount)
    if amount == 0 || (@response = gateway.purchase((amount * 100).to_i, billing_id)).success?
      s_payment = create_payment(amount,true)
      SubscriptionNotifier.deliver_misc_receipt(s_payment,fetch_pro_rata_description)
      true
    else
      errors.add_to_base(@response.message)
      false
    end
  end
  
  def charge_day_passes(quantity)
    amount_to_charge = quantity * day_pass_amount
    
    if(@response = gateway.purchase((amount_to_charge * 100).to_i, billing_id)).success?
      s_payment = subscription_payments.create(:account => account, 
                                               :amount => amount_to_charge, 
                                               :transaction_id => @response.authorization, 
                                               :misc => true, 
                                               :affiliate => affiliate,
                                               :meta_info => {:description => "Freshdesk daypass #{quantity}"})

      SubscriptionNotifier.deliver_day_pass_receipt(quantity, s_payment)
      s_payment
    else
      errors.add_to_base(@response.message)
      false
    end
  end
  
  def needs_payment_info?
    self.card_number.blank? && self.subscription_plan.amount > 0
  end
  
  def self.find_expiring_trials(renew_at = 7.days.from_now)
    find(:all, :include => :account, :conditions => { :state => 'trial', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
  end
  
  def self.find_due_trials(renew_at = Time.now)
    find(:all, :include => :account, :conditions => { :state => 'trial', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) }).select {|s| !s.card_number.blank? }
  end
  
  def self.find_due(renew_at = Time.now)
    find(:all, :include => :account, :conditions => { :state => ['active','free'], :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
  end

  def self.find_discount_expiry(discount_expiry = Time.now)
    find(:all, :include => :account, :conditions => { :discount_expires_at => (discount_expiry.beginning_of_day .. discount_expiry.end_of_day) })
  end

  def remove_discount
    self.discount = nil
    self.free_agents = subscription_plan.free_agents
    self.amount = total_amount
    update_without_callbacks
  end
  
  def current?
    next_renewal_at >= Time.now
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

  def sprout?
    subscription_plan.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout]
  end

  def classic?
    subscription_plan.classic
  end

  def eligible_for_free_plan?
    (account.full_time_agents.count <= AGENTS_FOR_FREE_PLAN)
  end

  def convert_to_free
    self.state = FREE if card_number.blank?
    self.agent_limit = AGENTS_FOR_FREE_PLAN
    self.renewal_period = 1
    self.next_renewal_at = Time.now.advance(:months => 1)
  end

  protected
  
    def set_billing
      self.billing_id = @response.params['customer_vault_id'] unless @response.params['customer_vault_id'].blank?
      if new_record?
        if !next_renewal_at? || next_renewal_at < 1.day.from_now.at_midnight
          if subscription_plan.trial_period?
            self.next_renewal_at = Time.now.advance(:months => subscription_plan.trial_period)
          else
            charge_amount = subscription_plan.setup_amount? ? subscription_plan.setup_amount : amount
            if (@response = gateway.purchase(charge_amount * 100, billing_id)).success?
              subscription_payments.build(:account => account, :amount => charge_amount, :transaction_id => @response.authorization, :setup => subscription_plan.setup_amount?)
              self.state = 'active'
              self.next_renewal_at = Time.now.advance(:months => renewal_period)
            else
              errors.add_to_base(@response.message)
              return false
            end
          end
        end
      else
        if (!next_renewal_at? || next_renewal_at < 1.day.from_now.at_midnight || @charge_now.eql?("true")) 
          if (amount == 0) ||  (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
            create_payment(amount) unless amount == 0
            self.state = 'active'
            self.next_renewal_at = Time.now.advance(:months => renewal_period)
          else
            errors.add_to_base(@response.message)
            return false
          end
        else
          self.state = 'active'
        end
        self.save
      end
    
      true
    end
    
    def set_renewal_at
      return if self.subscription_plan.nil? || self.next_renewal_at
      self.next_renewal_at = Time.now.advance(:months => self.renewal_period)
    end
    
    # If the discount is changed, set the amount to the discounted
    # plan amount with the new discount.
    def update_amount
      if subscription_discount_id_changed? || agent_limit_changed? || subscription_plan_id_changed? || renewal_period_changed?        
        total_amount
      end
    end
    
    def charge_plan_change_mis
      if  (amount > @old_subscription.amount) and active?  
        amt_to_charge = cal_plan_change_amount.round.to_f
        misc_charge(amt_to_charge) if amt_to_charge > PRO_RATA_MIN_CHARGE
      end
    end
    
    def paid_account?
      (state == 'active') and (subscription_payments.count > 0)
    end
    alias :is_paid_account :paid_account?
    
    def cal_plan_change_amount
     ((trial_days ) * (amount - @old_subscription.amount)) / no_of_days_in_term
    end
    
    def no_of_days_in_term
      no_of_days(renewal_period.months.from_now,Time.now)
    end
    
    def total_amount
      apply_the_discount
      apply_the_cycle
      self.amount = agent_limit ? (self.amount * paid_agents) : subscription_plan.amount
      self.amount = (amount > 0)?  amount : 0.00
    end

    def apply_the_discount
      self.subscription_discount = discount 
    end
    
    def apply_the_cycle
      self.amount = (subscription_plan.amount * subscription_plan.fetch_discount(renewal_period)).round.to_f
      self.amount = (amount * renewal_period) 
    end
    
    def chk_change_billing_cycle
      if renewal_period and (account.subscription.renewal_period > renewal_period) and paid_account? and (trial_days > 30)
        errors.add_to_base("You can't downgrade to lower billing cycle")
      end
    end
    
    def cache_old_model
      @old_subscription = Subscription.find id
    end
    
    def validate_on_update
      chk_change_billing_cycle
      if(agent_limit && agent_limit < account.full_time_agents.count)
       errors.add_to_base(I18n.t("subscription.error.lesser_agents", {:agent_count => account.agents.count}))
      end         
    end

    def available_free_agents
      agents = agent_limit || account.full_time_agents.count
      if (free_agents >= agents) 
        available_free_slots = (free_agents - agents).to_s + " available"
      else
        available_free_slots = free_agents
      end
      available_free_slots
    end

    def non_free_agents 
      non_free_agents =  (agent_limit || account.full_time_agents.count) - free_agents
      (non_free_agents > 0) ? non_free_agents : 0
    end
    
    def charge_if_free
      if (self.amount > 0 and @old_subscription.subscription_plan.free_plan? )
        if (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
          self.next_renewal_at = Time.now.advance(:months => renewal_period) 
          @trans_id = @response.authorization
          true
        else
          errors.add_to_base(@response.message)
          false
        end
      end
    end
 
    def send_invoice
      unless @trans_id.blank?
        subscription_payments.create(:account => account, :amount => amount, :transaction_id => @trans_id) 
      end
    end

    def finished_trial?
      next_renewal_at < Time.zone.now
    end

    def free_plan?
      self.subscription_plan.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:free]
    end
    
    def update_features
      return if subscription_plan_id == @old_subscription.subscription_plan_id
      SAAS::SubscriptionActions.new.change_plan(account, @old_subscription)
    end

    def paypal?
      card_number == 'paypal'
    end
    
    def gateway
      paypal? ? paypal : cc
    end
    
    def paypal
      @paypal ||=  ActiveMerchant::Billing::Base.gateway(:paypal_express_recurring).new(config_from_file('paypal.yml'))
    end
    
    def cc
      @cc ||= ActiveMerchant::Billing::Base.gateway(AppConfig['gateway']).new(config_from_file('gateway.yml'))
    end

    def destroy_gateway_record(gw = paypal? ? paypal : gateway)
      return if billing_id.blank?
      gw.unstore(billing_id)
      clear_billing_info
    end
    
    def clear_billing_info
      self.card_number = nil
      self.card_expiration = nil
      self.billing_id = nil
    end
    
    def card_storage
      self.store_card(@creditcard, :billing_address => @address.to_activemerchant) if @creditcard && @address && card_number.blank?
    end
    
    def config_from_file(file)
      YAML.load_file(File.join(RAILS_ROOT, 'config', file))[RAILS_ENV].symbolize_keys
    end
    
    def set_free_plan_agnt_limit
      self.agent_limit = AppConfig['free_plan_agts'] if free_plan?
   end
   
    def update_billing_address(address)
      billing_address = self.billing_address
      billing_address = build_billing_address unless billing_address
      [ :state, :zip, :first_name, :last_name,:address1,:address2, :city, :country].each do |field|
        billing_address[field] =  address.fetch(field)
      end
      billing_address.account = account
      billing_address.save
  end
  
  def fetch_pro_rata_description
    pro_rata_descrition = "Freshdesk #{SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[renewal_period]} Subscription Plan - #{subscription_plan.name} "
    pro_rata_descrition = "#{pro_rata_descrition} (#{agent_limit - @old_subscription.agent_limit} agents)" if agent_limit_changed? and agent_limit > @old_subscription.agent_limit
    pro_rata_descrition = "#{pro_rata_descrition} for #{trial_days} days"
    pro_rata_descrition
  end
  
  def create_payment(amount_to_charge,misc=false)
    subscription_payments.create(:account => account, 
                                 :amount => amount_to_charge, 
                                 :transaction_id => @response.authorization, 
                                 :affiliate => affiliate,
                                 :misc => misc,
                                 :meta_info => build_meta_info(misc))
  end
  
  def build_meta_info(misc)
    meta_info = {:plan => subscription_plan_id, 
                 :discount => subscription_discount_id, 
                 :agents => paid_agents,
                 :free_agents => free_agents,
                 :renewal_period => renewal_period}
    meta_info[:description] = fetch_pro_rata_description if misc
    meta_info
  end

  private

    def free_customer?
      (amount == 0 and active? ) || free?
    end

    def free_plan_selected?
      state_changed? and free?
    end

    def no_prorate?
      (amount < @old_subscription.amount) and 
        NO_PRORATION_PERIOD_CYCLES.include?(@old_subscription.renewal_period) unless @old_subscription.blank?
    end

    def add_to_crm
      Resque.enqueue(CRM::AddToCRM::FreeCustomer, id)
    end

    def update_billing
      Resque.enqueue(Billing::AddToBilling::UpdateSubscription, id, !no_prorate?)
    end 

    def add_card_to_billing
      Resque.enqueue(Billing::AddToBilling::StoreCard, id)
    end

    def activate_paid_customer_in_billing
      Resque.enqueue(Billing::AddToBilling::ActivateSubscription, id) if @old_subscription.state.eql?("trial")
    end

    def activate_free_customer_in_billing
      Resque.enqueue(Billing::AddToBilling::ActivateSubscription, id)
    end

 end
