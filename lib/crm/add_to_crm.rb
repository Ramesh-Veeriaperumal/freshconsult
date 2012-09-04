class CRM::AddToCRM
	@queue = "salesforceQueue"

	def self.perform(payment_id)
	 payment = SubscriptionPayment.find(payment_id)
	 crm = CRM::Salesforce.new
	 crm.add_data_to_crm(payment) unless Rails.env.development?
	end 
end