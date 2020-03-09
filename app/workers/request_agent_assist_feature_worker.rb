class RequestAgentAssistFeatureWorker < BaseWorker
  sidekiq_options queue: :agent_assist_email, retry: 0, failures: :exhausted

  def perform(_args)
    ::AgentAssistMailer.send(:request_feature_email)
    Account.current.account_additional_settings.update_agent_assist_config!(email_sent: true)
  rescue StandardError => e
    options_hash = {
      custom_params: {
        description: "Error in sending request agent assist feature Worker::Exception:: #{e.message}",
        account_id: Account.current.id,
        job_id: Thread.current[:message_uuid]
      }
    }
    NewRelic::Agent.notice_error(e, options_hash)
    Rails.logger.error("Error in sending request agent assist feature Worker A - #{Account.current.id}")
    Rails.logger.error("#{e.message} :: #{e.backtrace[0..10].join(', ')}")
  end
end
