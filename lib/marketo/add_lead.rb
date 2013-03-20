class Marketo::AddLead 
	@queue = "marketoQueue"

	def self.perform(args)
	 crm = ThirdCRM.new
	 account = Account.current
	 crm.add_signup_data(account, { :marketo_cookie => args[:cookie] }) unless Rails.env.development?
	end 
end