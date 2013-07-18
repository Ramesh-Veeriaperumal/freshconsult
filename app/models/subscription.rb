class Subscription < ActiveRecord::Base
  
  SUBSCRIPTION_TYPES = ["active", "trial", "free", "suspended"]
  
  AGENTS_FOR_FREE_PLAN = 3

  SUBSCRIPTION_ATTRIBUTES = { :account_id => :account_id, :amount => :amount, :state => :state,
                              :subscription_plan_id => :subscription_plan_id, :agent_limit => :agent_limit,
                              :free_agents => :free_agents, :renewal_period => :renewal_period, 
                              :subscription_discount_id => :subscription_discount_id }

  
  ACTIVE = "active"
  TRIAL = "trial"
  FREE = "free"
  
  belongs_to :account
  belongs_to :subscription_plan
  has_many :subscription_payments
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  
  has_one :billing_address,:class_name => 'Address',:as => :addressable,:dependent => :destroy
    

  before_create :set_renewal_at
  before_save :update_amount
  
  before_update :cache_old_model
  # after_update :update_features 

  after_update :add_to_crm, :if => :free_customer?

  attr_accessor :creditcard, :address, :billing_cycle
  attr_reader :response
  
  delegate :contact_info, :admin_first_name, :admin_last_name, :admin_email, :admin_phone, 
            :invoice_emails, :to => "account.account_configuration"
  delegate :name, :full_domain, :to => "account", :prefix => true

  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :only_integer => true, :greater_than => 0
  # validates_numericality_of :amount, :greater_than_or_equal_to => 0
  # validate_on_create :card_storage
  validates_inclusion_of :state, :in => SUBSCRIPTION_TYPES
  # validates_numericality_of :amount, :if => :free?, :equal_to => 0.00, :message => I18n.t('not_eligible_for_free_plan')
  validates_numericality_of :agent_limit, :if => :free?, :less_than_or_equal_to => AGENTS_FOR_FREE_PLAN, :message => I18n.t('not_eligible_for_free_plan')

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
 
  def self.monthly_revenue
    sum('amount/renewal_period', :conditions => [ " state = 'active' and amount > 0.00"]).to_f
  end


  def cmrr
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
    self.day_pass_amount = subscription_plan.day_pass_amount
    self.next_renewal_at = Time.now.advance(:months => 1)
  end

  protected
    
    def set_renewal_at
      return if self.subscription_plan.nil? || self.next_renewal_at
      self.next_renewal_at = Time.now.advance(:months => self.renewal_period)
    end
    
    # If the discount is changed, set the amount to the discounted
    # plan amount with the new discount.
    def update_amount
      if agent_limit_changed? || subscription_plan_id_changed? || renewal_period_changed?        
        total_amount
      end
    end
    
    def paid_account?
      (state == 'active') and (subscription_payments.count > 0)
    end
    alias :is_paid_account :paid_account?
    
    def total_amount
      if self.amount.blank?
        self.amount = subscription_plan.amount
      else
        response = Billing::Subscription.new.calculate_estimate(self)
        self.amount = (response.estimate.amount/100.0).round.to_f
      end
    end
    
    # def chk_change_billing_cycle
    #   if renewal_period and (account.subscription.renewal_period > renewal_period) and paid_account? and (trial_days > 30)
    #     errors.add_to_base("You can't downgrade to lower billing cycle")
    #   end
    # end
    
    def cache_old_model
      @old_subscription = Subscription.find id
    end
    
    def validate_on_update
      # chk_change_billing_cycle
      chk_change_agents unless trial?
    end

    def chk_change_agents 
      if(agent_limit && agent_limit < account.full_time_agents.count)
       errors.add_to_base(I18n.t("subscription.error.lesser_agents", {:agent_count => account.full_time_agents.count}))
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
 
    # def send_invoice
    #   unless @trans_id.blank?
    #     subscription_payments.create(:account => account, :amount => amount, :transaction_id => @trans_id) 
    #   end
    # end

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
    
    def clear_billing_info
      self.card_number = nil
      self.card_expiration = nil
      self.billing_id = nil
    end
    
    # def card_storage
    #   self.store_card(@creditcard, :billing_address => @address.to_activemerchant) if @creditcard && @address && card_number.blank?
    # end
    
    def config_from_file(file)
      YAML.load_file(File.join(RAILS_ROOT, 'config', file))[RAILS_ENV].symbolize_keys
    end
    
    def set_free_plan_agnt_limit
      self.agent_limit = AppConfig['free_plan_agts'] if free_plan?
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
      Resque.enqueue(CRM::AddToCRM::FreeCustomer, { :item_id => id, :account_id => account_id })
    end

 end
