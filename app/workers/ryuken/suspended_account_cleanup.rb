class Ryuken::SuspendedAccountCleanup
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:suspended_account_cleanup_queue], auto_delete: true,
                    body_parser: :json

  def perform(_sqs_msg, args)
    account = Account.current
    if enqueue_for_deletion?(account)
      Rails.logger.info "enqueuing account with #{account.id} to delete account worker"
      AccountCleanup::DeleteAccount.perform_async('account_id' => account.id)
    end
  rescue StandardError => e
    Rails.logger.error "suspended account cleanup exception - #{e.message} - #{e.backtrace[0..10]}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end

  private

    def enqueue_for_deletion?(account)
      account.subscription && account.subscription.suspended? && !not_suspended_within_expected_period?(account)
    end

    def not_suspended_within_expected_period?(account)
      account.subscription.updated_at.between?(6.months.ago.tomorrow.beginning_of_day, Time.now.utc)
    end
end
