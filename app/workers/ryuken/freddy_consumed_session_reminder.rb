# frozen_string_literal: true

class Ryuken::FreddyConsumedSessionReminder
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:freddy_consumed_session_reminder_queue], auto_delete: true,
                    body_parser: :json

  BREACH_LIMIT = 100
  EMAIL_REMINDER_HOURS = [24, 72].freeze

  def perform(sqs_msg, args)
    msg = JSON.parse(sqs_msg.body)
    properties = msg['data']['payload']['model_properties'].deep_symbolize_keys
    account_id = properties[:bundleType] ? properties[:anchorProductAccountId] : properties[:productAccountId]
    Sharding.select_shard_of(account_id) do
      account = ::Account.find(account_id)
      account.make_current
      return unless Account.current.subscription.freddy_sessions > 0

      sessions_consumed = properties[:consumedPercentage]
      sessions_count = properties[:sessionsConsumed]
      Bot::Emailbot::FreddyConsumedSessionWorker.perform_async(sessions_consumed: sessions_consumed, sessions_count: sessions_count)
      if sessions_consumed == BREACH_LIMIT
        EMAIL_REMINDER_HOURS.each do |reminder|
          Bot::Emailbot::FreddyConsumedSessionWorker.perform_in(reminder.hours.from_now, sessions_consumed: sessions_consumed, sessions_count: sessions_count)
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "Exception in Freddy Consumed Session Reminder - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end
end
