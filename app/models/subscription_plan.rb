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

  scope :get_details_by_name, ->(fields, names) { select(fields).where(name: names) }

  # TODO: Remove force_2019_plan?() after 2019 plan launched
  # START
  scope :plans_2019, conditions: { name: ['Sprout Jan 19', 'Blossom Jan 19', 'Garden Jan 19', 'Estate Jan 19','Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19'] }, :order => 'amount asc'
  # END

  after_commit :clear_cache

  SUBSCRIPTION_PLANS = { basic: 'Basic',
                         pro: 'Pro',
                         premium: 'Premium',
                         free: 'Free',
                         sprout_classic: 'Sprout Classic',
                         blossom_classic: 'Blossom Classic',
                         garden_classic: 'Garden Classic',
                         estate_classic: 'Estate Classic',
                         sprout: 'Sprout',
                         blossom: 'Blossom',
                         garden: 'Garden',
                         estate: 'Estate',
                         forest: 'Forest',
                         sprout_jan_17: 'Sprout Jan 17',
                         blossom_jan_17: 'Blossom Jan 17',
                         garden_jan_17: 'Garden Jan 17',
                         estate_jan_17: 'Estate Jan 17',
                         forest_jan_17: 'Forest Jan 17',
                         sprout_jan_19: 'Sprout Jan 19',
                         blossom_jan_19: 'Blossom Jan 19',
                         garden_jan_19: 'Garden Jan 19',
                         garden_omni_jan_19: 'Garden Omni Jan 19',
                         estate_jan_19: 'Estate Jan 19',
                         estate_omni_jan_19: 'Estate Omni Jan 19',
                         forest_jan_19: 'Forest Jan 19' }.freeze
   
   BILLING_CYCLE = [[:monthly, 'Monthly', 1],
                   [:quarterly, 'Quarterly', 3],
                   [:six_month, 'Half Yearly', 6],
                   [:annual, 'Annual', 12]].freeze

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

  JAN_2017_PLAN_NAMES = [
    'Sprout Jan 17', 'Blossom Jan 17', 'Garden Jan 17', 'Estate Jan 17', 'Forest Jan 17'
  ].freeze

  JAN_2019_PLAN_NAMES = [
    'Sprout Jan 19', 'Blossom Jan 19', 'Garden Jan 19', 'Estate Jan 19',
    'Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19'
  ].freeze

  PLAN_NAMES_BEFORE_2017_AND_NOT_GRAND_PARENT = [
    'Sprout', 'Blossom', 'Garden', 'Estate', 'Forest'
  ].freeze

  OMNI_PLANS = [
    ['Estate Omni Jan 19', 'Estate Jan 19'],
    ['Garden Omni Jan 19', 'Garden Jan 19']
  ].freeze

  OMNI_TO_BASIC_PLAN_MAP = OMNI_PLANS.each_with_object({}) do |plan, hash|
    hash[plan[0].to_sym] = plan[1]
  end.freeze

  BASIC_PLAN_TO_OMNI_MAP = OMNI_PLANS.each_with_object({}) do |plan, hash|
    hash[plan[1].to_sym] = plan[0]
  end.freeze
  
  PLANS_OMNI_COST = {
    'Garden Omni Jan 19': {
      EUR: 10.0, INR: 700.0, USD: 10.0, ZAR: 140.0, GBP: 9.0, AUD: 15.0, BRL: 40.0
    },
    'Estate Omni Jan 19': {
      EUR: 20.0, INR: 1500.0, USD: 20.0, ZAR: 285.0, GBP: 15.0, AUD: 25.0, BRL: 75.0
    },
    'Forest Jan 19': {
      EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0
    }
  }.freeze
  
  PLANS_FSM_COST = {
    'Estate Omni Jan 19': {
        EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0
    },
    'Estate Jan 19': {
        EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0
    },
    'Forest Jan 19': {
        EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0
    },
    'Garden Jan 19': {
        EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0
    },
    'Garden Omni Jan 19': {
        EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0
    }
  }.freeze

  FREE_OMNI_PLANS = ['Forest Jan 19'].freeze

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

  def omni_plan?
    OMNI_TO_BASIC_PLAN_MAP.key? name.to_sym
  end
  
  def basic_variant_name
    OMNI_TO_BASIC_PLAN_MAP[name.to_sym]
  end

  def basic_variant?
    BASIC_PLAN_TO_OMNI_MAP.key? name.to_sym
  end

  def omni_plan_name
    BASIC_PLAN_TO_OMNI_MAP[name.to_sym]
  end
  
  def omni_channel_cost(in_currency)
    costs = PLANS_OMNI_COST[name.to_sym]
    costs.nil? ? 0 : costs[in_currency.to_sym]
  end

  def fsm_cost(in_currency)
    PLANS_FSM_COST[name.to_sym] && PLANS_FSM_COST[name.to_sym][in_currency.to_sym]
  end

  def free_omni_channel_plan?
    FREE_OMNI_PLANS.include? name
  end

  def unlimited_multi_product?
    PLANS[:subscription_plans][canon_name][:features].include?(:unlimited_multi_product)
  end

  def multi_product?
    PLANS[:subscription_plans][canon_name][:features].include?(:multi_product)
  end
end
