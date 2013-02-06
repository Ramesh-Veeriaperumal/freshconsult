module Subscription::Events::CalculateRevenue

	def self.included(base)
    base.send :extend, ClassMethods
	end

	module ClassMethods

		include Subscription::Events::Constants

	  def revenue_type(code)
	    (code.eql?(CODES[:recurring])) ? REVENUE_TYPES[:existing] : REVENUE_TYPES[:new]
	  end

	  def calculate_cmrr(subscription, old_subscription, code)
	    (code.between?(CODES[:free], CODES[:free_to_paid])) ? new_business_revenue(subscription) : 
												existing_business_revenue(subscription, old_subscription)
	  end

	  def new_business_revenue(subscription)
	    subscription.amount/subscription.renewal_period
	  end

	  def existing_business_revenue(subscription, old_subscription)
	    (subscription.amount/subscription.renewal_period) - (old_subscription[:amount]/old_subscription[:renewal_period])
	  end

	end
end
