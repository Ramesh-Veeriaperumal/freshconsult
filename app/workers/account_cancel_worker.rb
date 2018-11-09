class AccountCancelWorker < BaseWorker
  sidekiq_options :queue => :cancel_account, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
      Account.current.perform_cancellation_for_paid_account if Account.current.account_cancellation_requested?
  rescue Exception => e
    Rails.logger.info "Error on account cancellation - #{e}"
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end
  
end
