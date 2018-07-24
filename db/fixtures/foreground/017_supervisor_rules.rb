account = Account.current

VaRule.create(
  rule_type: VAConfig::SUPERVISOR_RULE,
  name: "Automatically close resolved tickets after 48 hours",
  match_type: "all",
  filter_data: [
    { name: "status", operator: "is", value: Helpdesk::Ticketfields::TicketStatus::RESOLVED },
    { name: "resolved_at", operator: "greater_than", value: 48 } ],
  action_data: [
    { name: "status", value: Helpdesk::Ticketfields::TicketStatus::CLOSED } ],
  active: true,
  description: 'This rule will close all the resolved tickets after 48 hours.'
)

VaRule.create(
  rule_type: VAConfig::SUPERVISOR_RULE,
  name: "When a ticket has been overdue for a long time, assign it to the Escalations team",
  match_type: "all",
  filter_data: [
    { name: "status", operator: "is", value: Helpdesk::Ticketfields::TicketStatus::OPEN },
    { name: "due_by", operator: "greater_than", value: 2 } ],
  action_data: [
    {name: "group_id", value: account.groups.find_by_name("Escalations").id}],
  active: true,
  description: 'When a ticket has been overdue for 2 hours, assign it to the Escalations team to get them a response'
)  