class NewPlanChangeWorker < BaseWorker
  sidekiq_options :queue => :plan_change_workerv2, :retry => 0, :failures => :exhausted

  def perform(args)
  	args.symbolize_keys!
    account = Account.current
    
    features = args[:features]
    action   = args[:action].nil? ? "drop" : args[:action]
    SAAS::AccountDataCleanup.new(account, features, action).perform_cleanup
  rescue Exception => e
  	Rails.logger.info "Exception during account cleanup on downgrade"
  	NewRelic::Agent.notice_error(e)
  end
end