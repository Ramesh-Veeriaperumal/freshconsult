unless Account.current
  if Account.count == 0
    user = User.new(:name => 'Support', :password => 'test', :password_confirmation => 'test', 
                    :email => 'sample@freshdesk.com', :role_token => User::USER_ROLES_KEYS_BY_TOKEN[:account_admin])
    
    a = Account.create(:name => 'Test Account', :domain => 'localhost', :plan => SubscriptionPlan.last, :user => user)
    a.update_attribute(:full_domain, 'localhost')
    a.primary_email_config.update_attributes(:reply_email => "support@localhost", :to_email => "support@localhost")
    
    a.make_current
  else
    Account.first.make_current
  end
end
