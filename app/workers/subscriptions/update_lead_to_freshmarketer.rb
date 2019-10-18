class Subscriptions::UpdateLeadToFreshmarketer < BaseWorker
	include Sidekiq::Worker

	sidekiq_options :queue => :marketo_queue, :retry => 0, :failures => :exhausted

	def perform(args={})
    args.symbolize_keys!
	  account = Account.current
    return if account.opt_out_analytics_enabled?
	  ThirdCRM.new.add_or_update_contact(account, args)
  rescue => e
    Rails.logger.error "Exception while pushing lead data to Freshmarketer \
      acc_id: #{Account.current.try(:id)}, args: #{args.inspect}, error message: \
      #{e.message}, error: #{e.backtrace.join('\n')}"
    NewRelic::Agent.notice_error(e, description: "Exception while\
      pushing lead data to Freshmarketer acc_id: #{Account.current.try(:id)},\
      args: #{args.inspect}")
	end 
end
