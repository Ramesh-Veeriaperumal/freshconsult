load RAILS_ROOT+'/app/models/user.rb'

unless Account.current
  if Account.count == 0
    signup = Signup.new(  
      :account_name => 'Test Account',
      :account_domain => 'localhost',
      :locale => I18n.default_locale,
      
      :user_name => 'Support',
      :user_password => 'test',
      :user_password_confirmation => 'test', 
      :user_email => 'sample@freshdesk.com',
      :user_helpdesk_agent => true
    )
    signup.save
    signup.account.make_current
  else
    Account.first.make_current
  end
end