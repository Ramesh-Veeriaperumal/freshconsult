if Account.count == 0
  user = User.new(:name => 'Support', :password => 'test', :password_confirmation => 'test', 
                  :email => 'support@freshdesk.com', :role_token => 'admin')
  
  a = Account.create(:name => 'Test Account', :domain => 'localhost', :plan => SubscriptionPlan.first, :user => user)
  a.update_attribute(:full_domain, 'localhost')
end
