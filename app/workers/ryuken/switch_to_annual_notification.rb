class Ryuken::SwitchToAnnualNotification
  include Shoryuken::Worker
  include Redis::OthersRedis
  include Redis::RedisKeys

  shoryuken_options queue: ::SQS[:switch_to_annual_notification_queue], auto_delete: true,
                    body_parser: :json

  def perform(_sqs_msg, args)
    Rails.logger.info "Monthly to annual notification poller request - #{args.inspect} - #{_sqs_msg.inspect} - current_account: #{Account.current.inspect}"
    subscription = Account.current.subscription
    if !subscription.active? || subscription.renewal_period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] || Account.current.account_cancellation_requested?
      notification_offset = SubscriptionConstants::POSTPONE_NOTIFICATION_OFFSET # Notification months will be reduced by 3 months which actually will increase prior notifications by 1 month
      subscription.trigger_switch_to_annual_notification_scheduler(notification_offset) if subscription.trial?
      return
    end
    admin_users = Account.current.users.select { |user| user.privilege?(:admin_tasks) }
    admin_users.each { |user| user.agent.update_attributes(show_monthly_to_annual_notification: true) }
  rescue StandardError => e
    Rails.logger.error "Monthly to annual notification poller exception - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end
end
