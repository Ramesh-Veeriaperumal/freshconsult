class AccountCleanup::AnonymousAccountCleanup < BaseWorker
  sidekiq_options queue: :anonymous_account_cleanup, retry: 3, backtrace: true, failures: :exhausted

  def perform(args)
    Rails.logger.info "AnonymousAccountCleanup for account #{Account.current.id} ::: #{args}"
    Account.current.perform_account_cancellation if Account.current.anonymous_account?
  rescue StandardError => e
    Rails.logger.info "Error in AnonymousAccountCleanup for account #{Account.current.id} - #{e}"
    NewRelic::Agent.notice_error(e, args: args)
    raise e
  end
end
