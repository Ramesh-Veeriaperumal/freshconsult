class Subscription::PlanAddon < ActiveRecord::Base
	not_sharded

	belongs_to :subscription_plan
	belongs_to :subscription_addon
end