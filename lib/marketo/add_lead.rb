class Marketo::AddLead 
	extend Resque::AroundPerform
	
	@queue = "marketoQueue"

	def self.perform(args)
	 crm = ThirdCRM.new
	 account = Account.current
	 
	 crm.add_signup_data(account, { :marketo_cookie => args[:cookie] })
	end 
end