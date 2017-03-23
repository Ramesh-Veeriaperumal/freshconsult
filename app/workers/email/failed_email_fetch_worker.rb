module Email
  class FailedEmailFetchWorker

    include Shoryuken::Worker

    shoryuken_options queue: SQS[:fd_email_failure_reference], auto_delete: true, body_parser: :json,  batch: false
 
    def perform(sqs_msg, args)
      args = args.deep_symbolize_keys
      puts "FailedEmailFetchWorker:: Processing messages ::: #{sqs_msg} #{args}"
        Sharding.select_shard_of(args[:account_id]) do
          puts "FailedEmailFetchWorker:: inside sharding"
          account = Account.find(args[:account_id])
          if args[:note_id].present? and account and account.email_failures_enabled?
            puts "FailedEmailFetchWorker:: Going to process"
            account.make_current
            email_failure = Helpdesk::Email::FailedEmailMsg.new(args)
            email_failure.save!
            email_failure.notify
          else
            puts "FailedEmailFetchWorker:: note_id or account not available"
          end
        end
    rescue => e
      Rails.logger.info "Error in reading SQS-fd_email_failure_reference - #{e.message}"
      puts "FailedEmailFetchWorker:: Error in reading fd_email_failure_reference - #{e.message}"
    # ensure
    #   Account.reset_current_account
    end
  end
end