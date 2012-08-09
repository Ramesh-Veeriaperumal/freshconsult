class Marketo::AddLead 
	@queue = "marketoQueue"

	def self.perform(account_id, cookie)
	 crm = ThirdCRM.new
	 account = Account.find(account_id)
	 crm.add_signup_data(account, {:marketo_cookie => cookie}) #if Rails.env.production?
	end 
end