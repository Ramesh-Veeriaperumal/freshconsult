load "#{Rails.root}/app/models/user.rb"

unless Account.current
  if Account.count == 0
    signup = Signup.new(
      :account_name => 'Test Account',
      :account_domain => 'localhost',
      :locale => I18n.default_locale,
      :time_zone => "Chennai",
      :user_name => 'Support',
      :user_password => 'test1234',
      :user_password_confirmation => 'test1234',
      :user_email => Helpdesk::EMAIL[:sample_email],
      :user_helpdesk_agent => true
    )
    signup.save
    signup.account.make_current
  else
    Account.first.make_current
  end
  if Account.current
    subscription = Account.current.subscription
    if subscription.subscription_currency_id.nil?
      subscription.subscription_currency_id = 3 # Default USD
      subscription.state.downcase!
      subscription.sneaky_save
    end
  end
end
