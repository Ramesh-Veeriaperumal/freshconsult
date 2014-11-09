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
		:on_off => 1,
		:agent_quantity => 2,
		:portal_quantity => 3
	}

	  
	def self.fetch_addon(addon_id)
		find_by_name(addon_id.tr('_', ' ').titleize)		
	end

	def billing_addon_id
		name.tr(' ', '_').downcase.to_sym
	end

	def billing_quantity(subscription)
		ssl_certificate_count(subscription.account) if name.eql?("Custom Ssl")
		case addon_type
		when ADDON_TYPES[:agent_quantity]
			subscription.agent_limit		
		when ADDON_TYPES[:portal_quantity]
			subscription.account.portals.count	
		end
	end

	def features
		AddonConfig[name]
	end

	def allowed_in_plan?(plan)
		plan.addons.include?(self)
	end

	def ssl_certificate_count(account)
		account.portals.select{ |portal| portal.elb_dns_name.present? }.count
	end
end