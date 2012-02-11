unless Account.current
  if Account.count == 0
    user = User.new(:name => 'Support', :password => 'test', :password_confirmation => 'test', 
                    :email => 'sample@freshdesk.com', :role_token => User::USER_ROLES_KEYS_BY_TOKEN[:account_admin])
    
    a = Account.new(:name => 'Test Account', :domain => 'localhost', :plan => SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:garden]), :user => user)
    a.full_domain = 'localhost'
    a.build_primary_email_config(:reply_email => "support@localhost", :to_email => "support@localhost" , :name => a.name, :primary_role => true)
    a.primary_email_config.active = true
    a.primary_email_config.build_portal(:name => a.helpdesk_name || a.name, :preferences => HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"}), 
                               :language => I18n.default_locale.to_s() , :account => a)
    a.save
   
    a.make_current
  else
    Account.first.make_current
  end
end
