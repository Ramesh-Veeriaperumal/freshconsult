account = Account.current
ScenarioAutomation.seed_many(:account_id, :name, :rule_type, [
    [ 'Assign to QA', 'Customer reported bugs are assigned to QA in a single click',
        [
          { :name => "ticket_type", :value => "Problem" },
          { :name => "group_id", :value => account.groups.find_by_name("QA").id }
        ]],
    [ 'Mark as Feature Request', 'Feature Requests from customers can be marked accordingly and assigned to Product Management team.',
        [
          { :name => "ticket_type", :value => "Feature Request" },
          { :name => "group_id", :value => account.groups.find_by_name("Product Management").id }
        ]]
  ].map do |f|
    {
      :account_id => account.id,
      :rule_type => VAConfig::SCENARIO_AUTOMATION,
      :active => true,
      :name => f[0],
      :description => f[1],
      :action_data => f[2],
      :accessible_attributes => {
        :access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
      }
    }
  end
)