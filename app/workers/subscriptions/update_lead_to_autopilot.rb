class Subscriptions::UpdateLeadToAutopilot < BaseWorker
	include Sidekiq::Worker

	sidekiq_options :queue => :marketo_queue, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(args={})
    args.symbolize_keys!
	  account = Account.current
    return if account.opt_out_analytics_enabled?
	  ThirdCRM.new.add_or_update_contact(account, args)
  rescue => e
    Rails.logger.error "Exception while pushing lead data to Autopilot \
      acc_id: #{Account.current.id}, args: #{args.inspect}, error message: \
      #{e.message}, error: #{e.backtrace.join('\n')}"
    NewRelic::Agent.notice_error(error, description: "Exception while\
      pushing lead data to Autopilot acc_id: #{Account.current.id},\
      args: #{args.inspect}")
	end 
end