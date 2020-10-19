# frozen_string_literal: true

class Ryuken::FreddyConsumedSessionReminder
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:freddy_consumed_session_reminder_queue], auto_delete: true,
                    body_parser: :json

  BREACH_LIMIT = 100
  EMAIL_REMINDER_HOURS = [24, 72].freeze
  AUTO_RECHARGE_THRESHOLD = 500

  def perform(sqs_msg, args)
    msg = JSON.parse(sqs_msg.body)
    properties = msg['data']['payload']['model_properties'].deep_symbolize_keys
    account_id = properties[:bundleType] ? properties[:anchorProductAccountId] : properties[:productAccountId]
    Sharding.select_shard_of(account_id) do
      account = ::Account.find(account_id)
      account.make_current
      Rails.logger.info "Freddy consumed session poller request - #{args.inspect} - #{sqs_msg.inspect} - current_account: #{account.inspect}"
      return unless Account.current.subscription.freddy_sessions > 0

      if properties[:autoRechargeThresholdReached]
        process_auto_recharge(account)
      else
        sessions_consumed = properties[:consumedPercentage]
        sessions_count = properties[:sessionsConsumed]
        Bot::Emailbot::FreddyConsumedSessionWorker.perform_async(sessions_consumed: sessions_consumed, sessions_count: sessions_count)
        if sessions_consumed == BREACH_LIMIT
          EMAIL_REMINDER_HOURS.each do |reminder|
            Bot::Emailbot::FreddyConsumedSessionWorker.perform_in(reminder.hours.from_now, sessions_consumed: sessions_consumed, sessions_count: sessions_count)
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error "Exception in Freddy Consumed Session Reminder - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end

  def process_auto_recharge(account)
    if account.auto_recharge_eligible_enabled? && account.subscription.freddy_auto_recharge_enabled?
      Billing::Subscription.new.purchase_auto_recharge_addon(account, account.subscription.freddy_auto_recharge_packs)
      subscription = account.subscription
      subscription.freddy_sessions = subscription.freddy_sessions + (SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_auto_recharge_packs] * subscription.freddy_auto_recharge_packs)
      subscription.save!
    end
  end
end
