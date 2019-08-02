account = Account.current

VaRule.seed(:account_id, :name, :rule_type) do |s|
  s.account_id = account.id
  s.rule_type = VAConfig::BUSINESS_RULE
  s.name = 'Send refunds and returns to Billing - Sample Dispatcher rule'
  s.match_type = "any"
  s.filter_data = [
      {:evaluate_on => "ticket", :name => "subject_or_description", :operator => "contains", :value => "return" },
      {:evaluate_on => "ticket", :name => "subject_or_description", :operator => "contains", :value => "refund" } ]
  s.action_data = [
      { :name => "group_id", :value => account.groups.find_by_name("Billing").id } ]
  s.active = true
  s.description = 'This is a sample rule to help you understand how Dispatch\'r works. Feel free to edit or delete this rule.
In this example we will create a rule that will look at all incoming emails that have the text -"return" or "refund" and assigns them to "Billing" group.'
  s.condition_data = { any: [{ evaluate_on: 'ticket', name: 'subject_or_description',
                             operator: 'contains', value: 'return' },
                             { evaluate_on: 'ticket', name: 'subject_or_description',
                             operator: 'contains', value: 'refund' }] }


end
