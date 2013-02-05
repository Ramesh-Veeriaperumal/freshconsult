unless Account.current
  SubscriptionPlan.seed_many(:name, [
    { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00 },
    { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00 },
    { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00 },
    { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 4.00 }
  ])
end
