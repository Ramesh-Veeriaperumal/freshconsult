class Marketo::AddLead 
	extend Resque::AroundPerform

	@queue = "marketoQueue"

	def self.perform(args)
	  crm = ThirdCRM.new
	  account = Account.current
	  crm.add_signup_data(account, {:signup_id => args[:signup_id], :old_email => args[:old_email] })
	end 
end