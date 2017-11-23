class SubscriptionPlan < ActiveRecord::Base
  self.primary_key = :id
  not_sharded
  
  include ActionView::Helpers::NumberHelper
  include Cache::Memcache::SubscriptionPlan
  serialize :price, Hash
  
  has_many :subscriptions
  
  has_many :subscription_plan_addons, :class_name => "Subscription::PlanAddon", :source => :subscription_plan_addon
  has_many :addons,
    :class_name => "Subscription::Addon",
    :through => :subscription_plan_addons,
    :source => :subscription_addon
  
  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :trial_period, :only_integer => true, :greater_than => 0
  validates_presence_of :name
  
  attr_accessor :discount
  OLD_PLANS = ["Sprout", "Blossom", "Garden", "Estate", "Forest"]
  
  scope :current, :conditions => { :classic => false }, :order => 'amount asc'

  after_commit :clear_cache
  
  SUBSCRIPTION_PLANS = { 
    :basic => "Basic", 
    :pro => "Pro", 
    :premium => "Premium", 
    :free => "Free",
    :sprout_classic => "Sprout Classic",
    :blossom_classic => "Blossom Classic",
    :garden_classic => "Garden Classic",
    :estate_classic => "Estate Classic",
    :sprout => "Sprout",
    :blossom => "Blossom",
    :garden => "Garden",
    :estate => "Estate",
    :forest => "Forest",
    :sprout_jan_17 => "Sprout Jan 17",
    :blossom_jan_17 => "Blossom Jan 17",
    :garden_jan_17 => "Garden Jan 17",
    :estate_jan_17 => "Estate Jan 17",
    :forest_jan_17 => "Forest Jan 17"
  }
  
  BILLING_CYCLE = [
    [ :monthly,    I18n.t("subscription_plan.billing_cycle.monthly"),    1 ],
    [ :quarterly,  I18n.t("subscription_plan.billing_cycle.quarterly"),  3 ],
    [ :six_month,  I18n.t("subscription_plan.billing_cycle.sixmonth"),  6 ],
    [ :annual,     I18n.t("subscription_plan.billing_cycle.annual"),    12 ]
  ]

  BILLING_CYCLE_OPTIONS = BILLING_CYCLE.map { |i| [i[1], i[2]] }
  BILLING_CYCLE_NAMES_BY_KEY = Hash[*BILLING_CYCLE.map { |i| [i[2], i[1]] }.flatten]
  BILLING_CYCLE_KEYS_BY_TOKEN = Hash[*BILLING_CYCLE.map { |i| [i[0], i[2]] }.flatten]
  
  BILLING_CYCLE_DISCOUNT = {
    SUBSCRIPTION_PLANS[:premium] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:pro] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:basic] => { },
    SUBSCRIPTION_PLANS[:estate] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.82, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.90 },
    SUBSCRIPTION_PLANS[:garden] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:blossom] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:estate_classic] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.82, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.90 },
    SUBSCRIPTION_PLANS[:garden_classic] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:blossom_classic] => { 
      BILLING_CYCLE_KEYS_BY_TOKEN[:annual] => 0.85, BILLING_CYCLE_KEYS_BY_TOKEN[:six_month] => 0.95 },
    SUBSCRIPTION_PLANS[:sprout] => { },
    SUBSCRIPTION_PLANS[:sprout_classic] => { }
  }

  def fetch_discount(billing_cycle)
    BILLING_CYCLE_DISCOUNT[self.name].fetch(billing_cycle,1)
  end
  
  def to_s
    "#{self.name} - #{number_to_currency(self.amount)} / month"
  end
  
  def to_param
    self.name
  end
  
  def canon_name
    SUBSCRIPTION_PLANS.key(name)
  end
  
  def amount(include_discount = true)
    include_discount && @discount && check_right_plan && @discount.apply_to_recurring? ? self[:amount] - @discount.calculate(self[:amount]) : self[:amount]
  end
  
  def check_right_plan
    @discount.plan_id.nil? || @discount.plan_id ==self[:id]
  end
  
  def setup_amount(include_discount = true)
    include_discount && setup_amount? && @discount && @discount.apply_to_setup? ? self[:setup_amount] - @discount.calculate(self[:setup_amount]) : self[:setup_amount]
  end
  
  def trial_period(include_discount = true)
    include_discount && @discount ? self[:trial_period] + @discount.trial_period_extension : self[:trial_period]
  end
  
  def revenues
    @revenues ||= subscriptions.calculate(:sum, :amount, :group => 'subscriptions.state')
  end
  
  def self.get_free_plan_id
    find(:all, :select => :id , :conditions => {:name => SUBSCRIPTION_PLANS[:free]})
  end
  
  def self.previous_plans
    where(name: OLD_PLANS)
  end
  
  def free_plan?
    name == SUBSCRIPTION_PLANS[:free]
  end

  def pricing(currency)
    price[currency]
  end
  
end
