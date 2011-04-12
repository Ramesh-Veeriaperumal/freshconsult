account = Account.current

VARule.seed(:account_id, :name, :rule_type) do |s|
  s.account_id = account.id
  s.rule_type = VAConfig::BUSINESS_RULE
  s.name = "Send Leads to Sales - Sample Dispatch'r rule"
  s.match_type = "any"
  s.filter_data = [
      { :name => "subject_or_description", :operator => "contains", :value => "credit card" },
      { :name => "subject_or_description", :operator => "contains", :value => "purchase" } ]
  s.action_data = [
      { :name => "ticket_type", :value => TicketConstants::TYPE_KEYS_BY_TOKEN[:lead] }, #should we need to_s?
      { :name => "group_id", :value => account.groups.find_by_name("Sales").id } ]
  s.active = true
  s.description = 'This is a sample rule to help you understand how Dispatch\'r works. Feel free to edit or delete this rule.
In this example we will create a rule that will look at all incoming emails that have the text -"credit card" or "purchase" and marks those tickets as type "Lead" and assigns them to "Sales" group.'
end
