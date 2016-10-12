class Marketo::UpdateLeadToAutopilot
	extend Resque::AroundPerform

	@queue = "marketoQueue"

	def self.perform(args)
	  crm = ThirdCRM.new
	  account = Account.current
	  crm.update_subscription_data(account)
	end 
end