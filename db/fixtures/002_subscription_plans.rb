unless Account.current
  SubscriptionPlan.seed_many(:name, [
    { :name => 'Sprout', :amount => 9, :free_agents => 1, :day_pass_amount => 1.00 },
    { :name => 'Blossom', :amount => 19, :free_agents => 1, :day_pass_amount => 2.00 },
    { :name => 'Garden', :amount => 29, :free_agents => 1, :day_pass_amount => 2.00 }
  ])
end
