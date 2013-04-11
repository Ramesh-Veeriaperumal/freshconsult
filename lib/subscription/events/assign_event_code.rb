module Subscription::Events::AssignEventCode

	def self.included(base)
		base.send :extend, ClassMethods
	end

	module ClassMethods 

		include Subscription::Events::Constants

		ZERO_AMOUNT = 0.0

		#Code assignment
		def assign_code(subscription, old_subscription)
			case 
				when free?(subscription, old_subscription)
					CODES[:free]

				when affiliate?(subscription)
					CODES[:affiliates]

				when trial_to_paid?(subscription, old_subscription)
					CODES[:paid]

				when free_to_paid?(subscription, old_subscription)
					CODES[:free_to_paid]

				when recurring?(subscription, old_subscription)
					CODES[:recurring]

				when upgrade?(subscription, old_subscription)
					CODES[:upgrades] + additive(subscription, old_subscription)

				when downgrade?(subscription, old_subscription)
					notify_via_email(subscription, old_subscription)
					CODES[:downgrades] + additive(subscription, old_subscription)

				else
					nil
			end
		end

		def previously_trial?(old_subscription)
			old_subscription[:state].eql?(STATES[:trial])
		end

		def previously_free?(old_subscription)
			!(previously_trial?(old_subscription)) and old_subscription[:amount].eql?(ZERO_AMOUNT)
		end

		def previously_active?(old_subscription)
			old_subscription[:state].eql?(STATES[:active])
		end

		def paying_account?(subscription)
			subscription.active? and subscription.amount > ZERO_AMOUNT
		end

		#All events
		def free?(subscription, old_subscription)
			previously_trial?(old_subscription) and subscription.amount.eql?(ZERO_AMOUNT)
		end

		def affiliate?(subscription)
			subscription.active? and !(subscription.affiliate.blank?)
		end

		def trial_to_paid?(subscription, old_subscription)
			previously_trial?(old_subscription) and paying_account?(subscription)
		end

		def free_to_paid?(subscription, old_subscription)
			previously_free?(old_subscription) and paying_account?(subscription)
		end

		def recurring?(subscription, old_subscription)
			paying_account?(subscription) and subscription.amount.eql?(old_subscription[:amount]) and 
								!((subscription.next_renewal_at.to_s(:db)).eql?(old_subscription[:next_renewal_at]))
		end

		#Upgrades & Downgrades
		def upgrade?(subscription, old_subscription)
			previously_active?(old_subscription) and (subscription.amount > old_subscription[:amount])
		end

		def downgrade?(subscription, old_subscription)
			previously_active?(old_subscription) and (subscription.amount < old_subscription[:amount]) and
																						!additive(subscription, old_subscription).eql?(0)
		end

		def additive(subscription, old_subscription)
			agents_changed?(subscription, old_subscription) + plan_changed?(subscription, old_subscription) + 
									period_changed?(subscription, old_subscription)
		end

		def agents_changed?(subscription, old_subscription)
			(subscription.agent_limit.eql?(old_subscription[:agent_limit]))? 
									ADDITIVE_VALUES[:no_change] : ADDITIVE_VALUES[:agent_change]
		end

		def plan_changed?(subscription, old_subscription)
			(subscription.plan_id.eql?(old_subscription[:subscription_plan_id]))?
									ADDITIVE_VALUES[:no_change] : ADDITIVE_VALUES[:plan_change]
		end

		def period_changed?(subscription, old_subscription)
			(subscription.renewal_period.eql?(old_subscription[:renewal_period]))?
									ADDITIVE_VALUES[:no_change] : ADDITIVE_VALUES[:period_change]
		end

		def notify_via_email(subscription, old_subscription)
			SubscriptionNotifier.deliver_subscription_downgraded(subscription, 
																							old_subscription) if Rails.env.production?
		end
	end
end
