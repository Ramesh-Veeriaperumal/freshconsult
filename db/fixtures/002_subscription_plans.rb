unless Account.current
  SubscriptionPlan.seed_many(:name, [
    { :name => 'Basic', :amount => 9 },
    { :name => 'Pro', :amount => 19 },
    { :name => 'Premium', :amount => 29 },
    { :name => 'Free', :amount => 0 }
  ])
end
