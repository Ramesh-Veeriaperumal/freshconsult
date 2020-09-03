load "#{Rails.root}/app/models/user.rb"

unless Account.current
  unless $redis_others.perform_redis_op("exists", "FALCON_ENABLED_LANGUAGES")
    $redis_others.perform_redis_op("sadd", "FALCON_ENABLED_LANGUAGES", I18n.default_locale.to_s)
  end
  if Account.count == 0
    ChargeBee::Customer.stubs(:update).returns(true)
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
    ChargeBee::Customer.unstub(:update)
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
