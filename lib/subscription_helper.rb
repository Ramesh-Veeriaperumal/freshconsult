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
end
