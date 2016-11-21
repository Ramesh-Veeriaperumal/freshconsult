class Marketo::AddLead 
	extend Resque::AroundPerform

	@queue = "marketoQueue"

	def self.perform(args)    
	  crm = ThirdCRM.new
	  account = Account.current
	  crm.add_signup_data(account, {:signup_id => args[:signup_id] })
  ensure
    Resque.enqueue(CRM::Freshsales::Signup, { account_id: Account.current.id, fs_cookie: args[:fs_cookie] }) unless args[:skip_freshsales].present?
	end 
end