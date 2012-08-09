class Marketo::AddLead < Struct.new(:params)
	def perform
	 crm = ThirdCRM.new
	 account = Account.find(params[:account_id])
	 crm.add_signup_data(account,{:marketo_cookie => params[:marketo_cookie]}) if Rails.env.production?
	end 
end