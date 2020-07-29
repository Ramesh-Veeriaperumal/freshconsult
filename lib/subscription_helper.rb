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
        payload =
          {
            job_id: "#{Account.current.id}_activate_downgrade_#{reminder}",
            group: ::SchedulerClientKeys['downgrade_policy_group_name'],
            scheduled_time: (next_renewal_at_date - reminder.days).utc,
            data: {
              account_id: Account.current.id,
              enqueued_at: Time.now.to_i
            },
            sqs: {
              url: SQS_V2_QUEUE_URLS[SQS[:fd_scheduler_downgrade_policy_reminder_queue]]
            }
          }
        ::Scheduler::PostMessage.perform_async(payload: payload)
      end
    end
  end

  def product_loss_in_new_plan?(account, plan)
    account.has_feature?(:unlimited_multi_product) && !plan.unlimited_multi_product? &&
      plan.multi_product? && account.products.count > AccountConstants::MULTI_PRODUCT_LIMIT
  end
end
