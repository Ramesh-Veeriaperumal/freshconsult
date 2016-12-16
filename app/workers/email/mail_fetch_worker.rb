module Email
  class MailFetchWorker

    include Shoryuken::Worker

    MAIL_PROCESSING_SQS_QUEUES = [
      SQS[:trial_customer_email_queue], 
      SQS[:active_customer_email_queue],
      SQS[:free_customer_email_queue],
      SQS[:default_email_queue]
    ]

    shoryuken_options queue: ->{ MAIL_PROCESSING_SQS_QUEUES }, auto_delete: false, body_parser: :json, batch: false

    def perform(sqs_msg, args)
      begin
        params = args.merge(:message_attributes => { :receipt_handle => sqs_msg.receipt_handle, :queue_name => sqs_msg.queue_name })
        params = params.with_indifferent_access
        Helpdesk::Email::MailMessageProcessor.new(params).execute
      rescue => e
        Rails.logger.info "Error in MailFetchWorker - #{e.message} - #{e.backtrace}"
      end
    end
  end
end
