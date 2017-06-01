require 'newrelic_rpm'

module Email
  class MailFetchWorker

    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

    include Shoryuken::Worker

    MAIL_PROCESSING_SQS_QUEUES = [
      SQS[:trial_customer_email_queue], 
      SQS[:active_customer_email_queue],
      SQS[:free_customer_email_queue],
      SQS[:default_email_queue]
    ]

    shoryuken_options queue: ->{ MAIL_PROCESSING_SQS_QUEUES }, auto_delete: false, body_parser: :json, batch: false

    def perform(sqs_msg, args)
      start = Time.now
      begin
        params = args.merge(:message_attributes => { :receipt_handle => sqs_msg.receipt_handle, :queue_name => sqs_msg.queue_name })
        params = params.with_indifferent_access
        Helpdesk::Email::MailMessageProcessor.new(params).execute
      rescue => e
        Rails.logger.info "Error in MailFetchWorker - #{e.message} - #{e.backtrace}"
        NewRelic::Agent.notice_error(e, {:description => "Error in MailFetchWorker - Params : #{params.inspect}"})
      ensure
        elapsed_time = (Time.now - start).round(3)
        Rails.logger.info "Time taken for mailfetchworker perform : #{elapsed_time} seconds - UID : #{params[:uid]} path - #{params[:email_path]} "
      end
    end

    add_transaction_tracer :perform, :category => :task
  end
end
