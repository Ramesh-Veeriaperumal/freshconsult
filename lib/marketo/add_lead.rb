class Marketo::AddLead 
	extend Resque::AroundPerform

	@queue = "marketoQueue"

	def self.perform(args)
	  crm = ThirdCRM.new
	  account = Account.current
	  Rails.logger.error("Marketo::AddLead check for spam account account_id: #{account.id} spam: #{account.ehawk_spam?}")
	  return if account.ehawk_spam?
	  crm.add_signup_data(account, {:signup_id => args[:signup_id], :old_email => args[:old_email] })
	end 
end
