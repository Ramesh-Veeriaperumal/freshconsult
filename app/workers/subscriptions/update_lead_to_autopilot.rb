class Subscriptions::UpdateLeadToAutopilot < BaseWorker
	include Sidekiq::Worker

	sidekiq_options :queue => :marketo_queue, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(args = {})
	  crm = ThirdCRM.new
	  account = Account.current
    return if account.opt_out_analytics_enabled?
	  crm.update_subscription_data(account)
	end 
end