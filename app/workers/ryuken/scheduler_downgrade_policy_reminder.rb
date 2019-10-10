class Ryuken::SchedulerDowngradePolicyReminder
  include Shoryuken::Worker
  include Redis::OthersRedis
  include Redis::RedisKeys

  shoryuken_options queue: ::SQS[:fd_scheduler_downgrade_policy_reminder_queue], auto_delete: true,
                    body_parser: :json

  def perform(_sqs_msg, args)
    current_account = Account.current
    subscription = current_account.subscription
    return unless subscription.subscription_request.present? || current_account.account_cancellation_requested?

    next_renewal_at = subscription.next_renewal_at
    remaining_days = (next_renewal_at.utc.to_date - DateTime.now.utc.to_date).to_i
    reminder_key = current_account.downgrade_policy_email_reminder_key
    unless redis_key_exists?(reminder_key)
      set_others_redis_key(reminder_key, true, remaining_days.days.seconds.to_i)
    end
    reminder_type = current_account.account_cancellation_requested? ? :cancel : :downgrade
    
    DowngradePolicyReminderMailer.send_email_to_group(:send_reminder_email,
      current_account.fetch_all_admins_email, subscription, remaining_days, reminder_type)
  rescue StandardError => e
    Rails.logger.error "Downgrade Policy Reminder scheduler poller exception - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, { arguments: args })
    raise e
  end
end
