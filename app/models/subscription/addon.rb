include Redis::OthersRedis
class Subscription::Addon < ActiveRecord::Base
  self.primary_key = :id
	not_sharded
	
	has_many :subscription_plan_addons, 
		:class_name => "Subscription::PlanAddon",
		:foreign_key => :subscription_addon_id
	has_many :plans,
		:class_name => "SubscriptionPlan",
		:through => :subscription_plan_addons,
		:source => :subscription_plan

  has_many :subscription_addon_mappings, 
    :class_name => "Subscription::AddonMapping",
    :foreign_key => :subscription_addon_id
  has_many :subscriptions,
    :through => :subscription_addon_mappings

  validates_uniqueness_of :name
  validates_presence_of :amount, :greater_than => 0
  validates_presence_of :renewal_period, :only_integer => true, :greater_than => 0

  ADDON_TYPES = {
    on_off:                1,
    agent_quantity:        2,
    portal_quantity:       3,
    for_account:           4,
    field_agent_quantity:  5,
    session_packs:         6
  }.freeze

  FSM_ADDON = 'Field Service Management'.freeze
  FSM_ADDON_2020 = 'Field Service Management 20'.freeze

  FREDDY_SELF_SERVICE_ADDON = 'Freddy Self Service'.freeze
  FREDDY_ULTIMATE_ADDON = 'Freddy Ultimate'.freeze
  FREDDY_SESSION_PACKS_ADDON = 'Freddy Session Packs'.freeze

  FREDDY_MONTHLY_SESSION_PACKS_ADDON = 'Freddy Session Packs Monthly'.freeze
  FREDDY_QUARTERLY_SESSION_PACKS_ADDON = 'Freddy Session Packs Quarterly'.freeze
  FREDDY_HALF_YEARLY_SESSION_PACKS_ADDON = 'Freddy Session Packs Half Yearly'.freeze
  FREDDY_ANNUAL_SESSION_PACKS_ADDON = 'Freddy Session Packs Annual'.freeze

  def self.fetch_addon(addon_id)
    find_by_name(addon_id.tr('_', ' ').titleize) 
  end

  def billing_addon_id
    name.tr(' ', '_').downcase.to_sym
  end

  def billing_quantity(subscription)
    ssl_certificate_count(subscription.account) if name.eql?('Custom Ssl')
    case addon_type
    when ADDON_TYPES[:agent_quantity]
      subscription.agent_limit
    when ADDON_TYPES[:portal_quantity]
      subscription.account.portals.count
    when ADDON_TYPES[:for_account]
      1
    when ADDON_TYPES[:field_agent_quantity]
      subscription.field_agent_limit
    when ADDON_TYPES[:session_packs]
      subscription.freddy_session_packs
    end
  end

  def features
    AddonConfig[name]
  end

  def allowed_in_plan?(plan)
    plan.addons.include?(self)
  end

  def ssl_certificate_count(account)
    account.portals.select { |portal| portal.elb_dns_name.present? }.count
  end
end
