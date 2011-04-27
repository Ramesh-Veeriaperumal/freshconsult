unless Account.current
  SubscriptionPlan.seed_many(:name, [
    { :name => 'Basic', :amount => 0, :user_limit => 2 },
    { :name => 'Pro', :amount => 10, :user_limit => 5 },
    { :name => 'Premium', :amount => 30, :user_limit => nil }
  ])
end
