class CRM::AddToCRM
	QUEUE = "salesforceQueue"
	
	class PaidCustomer
		@queue = QUEUE

		def self.perform(payment_id)
			payment = SubscriptionPayment.find(payment_id)
			crm = CRM::Salesforce.new
			crm.add_paid_customer_to_crm(payment) #unless Rails.env.development?
		end
	end 

	class FreeCustomer
		@queue = QUEUE

		def self.perform(subscription_id)
			subscription = Subscription.find(subscription_id)
			crm = CRM::Salesforce.new
			crm.add_free_customer_to_crm(subscription) #unless Rails.env.development?
		end
	end

	# class Customer
	# 	@queue = "salesforceQueue"

	# 	def self.perform(item_id)
	# 		item = scoper.find(item_id)
	# 		crm = CRM::Salesforce.new
	# 		perform_job(crm, item)
	# 	end
	# end

	# class PaidCustomer < Customer
	# 	def self.scoper
	# 		SubscriptionPayment
	# 	end

	# 	def self.perform_job(crm, item)
	# 		crm.add_paid_customer_to_crm(item)
	# 	end
	# end
end
