account = Account.current

VARule.seed(:account_id, :name, :rule_type) do |s|
  s.account_id = account.id
  s.rule_type = VAConfig::SUPERVISOR_RULE
  s.name = "Automatically close resolved tickets after 48 hours"
  s.match_type = "all"
  s.filter_data = [
      { :name => "status", :operator => "is", :value => Helpdesk::Ticketfields::TicketStatus::RESOLVED },
      { :name => "resolved_at", :operator => "greater_than", :value => 48 } ]
  s.action_data = [
      { :name => "status", :value => Helpdesk::Ticketfields::TicketStatus::CLOSED } ]
  s.active = true
  s.description = 'This rule will close all the resolved tickets after 48 hours.'
end
