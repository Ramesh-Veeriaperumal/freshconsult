module SubscriptionHelper

  TICKET_DESCRIPTION_TEMPLATE = "Customer has switched to / purchased an Omni-channel Freshdesk plan. <br> \
    <b>Account ID</b> : %{account_id}<br><b>Domain</b> : %{full_domain}<br><b>Current plan</b> \
    : %{plan_name}<br><b>Currency</b> : %{currency_name}<br><b>Previous plan</b> : \
    %{old_plan_name}<br><b>Contact</b> : %{user_email}<br>Ensure plan is set correctly in chat and caller.".freeze
  TICKET_PARAMS = {
    email: 'billing@freshdesk.com',
    subject: 'Update chat and caller plans',
    status: Helpdesk::Ticketfields::TicketStatus::OPEN,
    priority: Helpdesk::Ticket::PRIORITY_KEYS_BY_TOKEN[:low],
    tags: 'OmnichannelPlan'
  }.freeze

  EMAIL_REMINDER_DAYS = [7, 3, 1].freeze
  SWITCH_TO_ANNUAL_NOTIFICATION_MONTHS = [4, 8, 12].freeze

  def omni_channel_ticket_params(account, old_subscription, user)
    description = format(TICKET_DESCRIPTION_TEMPLATE,
                         account_id: account.id,
                         full_domain: account.full_domain,
                         plan_name: account.subscription.plan_name,
                         currency_name: account.subscription.currency.name,
                         old_plan_name: old_subscription.plan_name,
                         user_email: user.try(:email))
    TICKET_PARAMS.merge(description: description)
  end

  def omni_plan_change?(old_subscription, new_subscription)
    old_subscription.subscription_plan.omni_plan? ||
      old_subscription.subscription_plan.free_omni_channel_plan? ||
      new_subscription.subscription_plan.omni_plan? || new_subscription.subscription_plan.free_omni_channel_plan?
  end

  def trigger_downgrade_policy_reminder_scheduler(next_renewal_at = nil)
    next_renewal_at_date = next_renewal_at.present? ? next_renewal_at : Account.current.subscription.next_renewal_at
    remaining_days = (next_renewal_at_date.utc.to_date - DateTime.now.utc.to_date).to_i
    EMAIL_REMINDER_DAYS.each do |reminder|
      if remaining_days - reminder >= 0
        post_message_to_scheduler("#{Account.current.id}_activate_downgrade_#{reminder}", 'downgrade_policy_group_name', (next_renewal_at_date - reminder.days).utc, :fd_scheduler_downgrade_policy_reminder_queue)
      end
    end
  end

  def trigger_switch_to_annual_notification_scheduler(notification_offset = 0)
    cancel_existing_switch_to_annual_notification_scheduler if notification_offset != 0
    SWITCH_TO_ANNUAL_NOTIFICATION_MONTHS.each do |notification_month|
      post_message_to_scheduler("#{Account.current.id}_switch_to_annual_#{notification_month}", 'monthly_to_annual_group_name', DateTime.now.utc + (notification_month + notification_offset).months, :switch_to_annual_notification_queue)
    end
  end

  def cancel_existing_switch_to_annual_notification_scheduler
    job_ids = SWITCH_TO_ANNUAL_NOTIFICATION_MONTHS.map { |month| "#{Account.current.id}_switch_to_annual_#{month}" }
    Scheduler::CancelMessage.perform_async(job_ids: job_ids, group_name: SchedulerClientKeys['monthly_to_annual_group_name'])
  end

  def post_message_to_scheduler(job_id, scheduler_group_name, scheduled_time, sqs_queue_name)
    payload = {
      job_id: job_id,
      group: ::SchedulerClientKeys[scheduler_group_name],
      scheduled_time: scheduled_time,
      data: {
        account_id: Account.current.id,
        enqueued_at: Time.now.to_i
      },
      sqs: {
        url: SQS_V2_QUEUE_URLS[SQS[sqs_queue_name]]
      }
    }
    Scheduler::PostMessage.perform_async(payload: payload)
  end

  def product_loss_in_new_plan?(account, plan)
    account.has_feature?(:unlimited_multi_product) && !plan.unlimited_multi_product? &&
      plan.multi_product? && account.products.count > AccountConstants::MULTI_PRODUCT_LIMIT
  end
end
