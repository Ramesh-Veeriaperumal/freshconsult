class Subscriptions::AddLead < BaseWorker
	include Sidekiq::Worker

	sidekiq_options :queue => :marketo_queue, :retry => 0, :failures => :exhausted

	def perform(args = {})
	  crm = ThirdCRM.new
	  account = Account.current
	  Rails.logger.error("AddLead check for spam account account_id: #{account.id} spam: #{account.ehawk_spam?}")
	  return if account.ehawk_spam? || account.opt_out_analytics_enabled?
	  crm.add_signup_data(account, {:signup_id => args[:signup_id], :old_email => args[:old_email] })
	end
end