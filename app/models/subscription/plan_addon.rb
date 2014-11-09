class Subscription::PlanAddon < ActiveRecord::Base
  self.primary_key = :id
	not_sharded

  # TODO-RAILS3 need to cross check all places do we need to add class_name while we are using thorugh in has_many association
	belongs_to :subscription_plan, :class_name => "SubscriptionPlan"
	belongs_to :subscription_addon, :class_name => "Subscription::Addon"
end