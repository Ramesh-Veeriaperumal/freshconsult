class Subscription < ActiveRecord::Base
  
  PRO_RATA_MIN_CHARGE = 4.00
  
  belongs_to :account
  belongs_to :subscription_plan
  has_many :subscription_payments
  belongs_to :discount, :class_name => 'SubscriptionDiscount', :foreign_key => 'subscription_discount_id'
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'
  
  before_create :set_renewal_at
  before_update  :cache_old_model,:set_free_plan_agnt_limit, :charge_if_free,:charge_plan_change_mis
  before_destroy :destroy_gateway_record
  before_validation :update_amount
  after_update :update_features,:send_invoice
  
  attr_accessor :creditcard, :address, :billing_cycle
  attr_reader :response
  
  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :only_integer => true, :greater_than => 0
  validates_numericality_of :amount, :greater_than_or_equal_to => 0
  validate_on_create :card_storage
  
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
    else
      # Free account from the get-go?  No point in having a trial
      self.state = 'active' #if new_record?
    end
    
    self.renewal_period = billing_cycle unless billing_cycle.nil?
    self.subscription_plan = plan
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
  
  def store_card(creditcard, gw_options = {})
    # Clear out payment info if switching to CC from PayPal
    destroy_gateway_record(paypal) if paypal?
    @charge_now = gw_options[:charge_now]
    @response = if billing_id.blank?
      gateway.store(creditcard, gw_options)
    else
      gateway.update(billing_id, creditcard, gw_options)
    end
    
    if @response.success?
      self.card_number = creditcard.display_number
      self.card_expiration = "%02d-%d" % [creditcard.expiry_date.month, creditcard.expiry_date.year]
      set_billing
    else
      puts errors.to_json
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
        update_attributes(:next_renewal_at => self.next_renewal_at.advance(:months => self.renewal_period), :state => 'active')
        subscription_payments.create(:account => account, :amount => amount, :transaction_id => @response.authorization) unless amount == 0
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
      subscription_payments.create(:account => account, :amount => amount, :transaction_id => @response.authorization, :misc => true)
      true
    else
      errors.add_to_base(@response.message)
      false
    end
  end
  
  def start_paypal(return_url, cancel_url)
    if (@response = paypal.setup_agreement(:return_url => return_url, :cancel_return_url => cancel_url, :description => AppConfig['app_name'])).success?
      paypal.redirect_url_for(@response.params['token'])
    else
      errors.add_to_base("PayPal Error: #{@response.message}")
      false
    end
  end
  
  def complete_paypal(token)
    # Make sure the paypal subscription gets started tomorrow at the 
    # earliest
    start_date = next_renewal_at < 1.day.from_now.at_beginning_of_day ? 1.day.from_now : next_renewal_at
    
    if (@response = paypal.create_profile(token, :description => AppConfig['app_name'], :start_date => start_date, :frequency => renewal_period, :amount => amount_in_pennies)).success?

      # Clear out payment info if changing the PayPal billing
      # info or if switching from a CC
      if paypal?
        destroy_gateway_record(paypal)
      else
        destroy_gateway_record(cc)
      end

      self.card_number = 'PayPal'
      self.card_expiration = 'N/A'
      self.state = 'active'
      self.billing_id = @response.params['profile_id']
      # Sync up our next renewal date with PayPal.
      self.next_renewal_at = Time.parse(paypal.get_profile_details(@response.params['profile_id']).params['next_billing_date'])
      save
    else
      errors.add_to_base("PayPal Error: #{@response.message}")
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
    find(:all, :include => :account, :conditions => { :state => 'active', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
  end
  
  def paypal?
    card_number == 'PayPal'
  end
  
  def current?
    next_renewal_at >= Time.now
  end
  
  def purge_paypal
    return true if billing_id.blank?
    if (@response = paypal.unstore(billing_id)).success?
      clear_billing_info
      return save
    else
      errors.add_to_base(@response.message)
      return false
    end
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
        if (!next_renewal_at? || next_renewal_at < 1.day.from_now.at_midnight || @charge_now.eql?("true")) and amount > 0
          if (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
            subscription_payments.build(:account => account, :amount => amount, :transaction_id => @response.authorization)
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
        subscription_plan.discount = discount 
        total_amount
      end
    end
    
    def charge_plan_change_mis
      if  (amount > @old_subscription.amount) and paid_account?  
        amt_to_charge = cal_plan_change_amount.round.to_f
        misc_charge(amt_to_charge) if amt_to_charge > PRO_RATA_MIN_CHARGE
      end
    end
    
    def paid_account?
      (state == 'active') and (subscription_payments.count > 0)
    end
    
    def cal_plan_change_amount
     ((trial_days ) * (amount - @old_subscription.amount)) / no_of_days_in_term
    end
    
    def no_of_days_in_term
      no_of_days(renewal_period.months.from_now,Time.now)
    end
    
    def total_amount
      apply_the_cycle
      self.amount = agent_limit ? (self.amount * agent_limit) : subscription_plan.amount
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
      return if self.amount == 0      
      if(agent_limit && agent_limit < account.agents.count)
       errors.add_to_base(I18n.t("subscription.error.lesser_agents", {:agent_count => account.agents.count}))end         
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

    def free_plan?
      self.subscription_plan.name == SubscriptionPlan::SUBSCRIPTION_PLANS[:free]
    end
    
    def update_features
      return if subscription_plan_id == @old_subscription.subscription_plan_id
      SAAS::SubscriptionActions.new.change_plan(account, @old_subscription)
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
  
end
