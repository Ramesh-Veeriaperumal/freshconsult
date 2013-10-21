account = Account.current

VARule.seed_many(:account_id, :name, :rule_type, [
    [ 'Assign to QA', 'Customer reported bugs are assigned to QA in a single click',
        [
          { :name => "ticket_type", :value => "Problem" },
          { :name => "group_id", :value => account.groups.find_by_name("QA").id }
        ]],
    [ 'Mark as Feature Request', 'Feature Requests from customers can be marked accordingly and assigned to Product Management team.',
        [
          { :name => "ticket_type", :value => "Feature Request" },
          { :name => "group_id", :value => account.groups.find_by_name("Product Management").id }
        ]],
    [ 'Send Welcome Email - Canned Response', 'You can use scenario automations to send canned responses to users.',
        [
          { :name => "send_email_to_requester",
            :email_body => "Hi {{ticket.requester.name}}

Welcome to {{helpdesk_name}}! My name is {{ticket.agent.name}} and I will be your account manager. 

You can email me at {{ticket.agent.email}} if you need any help outside of our standard helpdesk services.

Regards
{{ticket.agent.name}}"
          }
        ]]
  ].map do |f|
    {
      :account_id => account.id,
      :rule_type => VAConfig::SCENARIO_AUTOMATION,
      :active => true,
      :name => f[0],
      :description => f[1],
      :action_data => f[2]
    }
  end
)
