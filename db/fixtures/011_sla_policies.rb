account = Account.current

policy = Helpdesk::SlaPolicy.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = 'Default SLA Policy'
  s.description = 'default policy'
  s.is_default = true
end

Helpdesk::SlaDetail.seed_many(:sla_policy_id, :priority, [
  {
      :name => 'Sla for low priority',      
      :sla_policy_id => policy.id, 
      :priority => 1,      
      :response_time => 86400,
      :resolution_time => 259200,
      :override_bhrs => false
  },
  
  {   
      :name => 'Sla for medium priority', 
      :sla_policy_id => policy.id, 
      :priority => 2,
      :response_time => 28800,
      :resolution_time => 86400,
      :override_bhrs => false
  },
  
  {   
      :name => 'Sla for high priority', 
      :sla_policy_id => policy.id, 
      :priority => 3,
      :response_time => 14400,
      :resolution_time => 43200,
      :override_bhrs => false
  },
  
  {   
      :name => 'Sla for urgent priority',      
      :sla_policy_id => policy.id, 
      :priority => 4,
      :response_time => 3600,
      :resolution_time => 14400,
      :override_bhrs => false
  }
])
