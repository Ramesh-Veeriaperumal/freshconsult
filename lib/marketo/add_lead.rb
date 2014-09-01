class Marketo::AddLead 
	extend Resque::AroundPerform

	@queue = "marketoQueue"

	def self.perform(args)
	 crm = ThirdCRM.new
	 account = Account.current
	 cookie_info = args[:cookie].blank? ? {} : args[:cookie].symbolize_keys!

	 crm.add_signup_data(account, { :marketo_cookie => cookie_info[:marketo], 
	 	:analytics_cookie => cookie_info[:analytics],
	 	:signup_id => args[:signup_id] }) if Rails.env.production?
	end 
end