account = Account.first

policy = Helpdesk::SlaPolicy.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = 'Default SLA Policy'
  s.description = 'default policy'
  s.is_default = true
end

Helpdesk::SlaDetail.seed_many(:account_id, :sla_policy_id, :priority, [
  {
      :name => 'Sla for low priority', 
      :account_id => account.id, 
      :sla_policy_id => policy.id, 
      :priority => 1,
      :response_time => 86400,
      :resolution_time => 259200
  },
  
  {   
      :name => 'Sla for medium priority', 
      :account_id => account.id, 
      :sla_policy_id => policy.id, 
      :priority => 2,
      :response_time => 28800,
      :resolution_time => 86400
  },
  
  {   
      :name => 'Sla for high priority', 
      :account_id => account.id, 
      :sla_policy_id => policy.id, 
      :priority => 3,
      :response_time => 14400,
      :resolution_time => 43200
  },
  
  {   
      :name => 'Sla for urgent priority', 
      :account_id => account.id, 
      :sla_policy_id => policy.id, 
      :priority => 4,
      :response_time => 3600,
      :resolution_time => 14400
  }
])
