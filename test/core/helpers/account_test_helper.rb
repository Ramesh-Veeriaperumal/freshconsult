module AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def create_test_account(name = "test_account", domain = "test@freshdesk.local")
    subscription = Subscription.where("state != 'suspended'").first
    @account = Account.find_by_id(subscription.account_id) unless subscription.nil?
    if @account.nil?
      ENV["SEED"]="global/002_subscription_plans"
      ENV["FIXTURE_PATH"] = "db/fixtures/global"
      SeedFu::PopulateSeed.populate
      ENV["SEED"] = nil
      ENV["FIXTURE_PATH"] = nil
      create_new_account
      update_currency 
    else
      @account.make_current
    end
    create_dummy_customer
  end

  def create_new_account(domain = "localhost", user_email = Helpdesk::EMAIL[:sample_email])
    signup = Signup.new(  
      :account_name => 'Test Account',
      :account_domain => domain,
      :locale => I18n.default_locale,
      :user_name => 'Support',
      :user_password => 'test1234',
      :user_password_confirmation => 'test1234', 
      :user_email => user_email,
      :user_helpdesk_agent => true
    )
    signup.save
    
    PopulateGlobalBlacklistIpsTable.create_default_record
    @account = signup.account.make_current
  end

  def disable_background_fixtures
    remove_others_redis_key(BACKGROUND_FIXTURES_ENABLED)
  end

  def enable_background_fixtures
    set_others_redis_key(BACKGROUND_FIXTURES_ENABLED, 1, nil)
  end

  def create_dummy_customer
    @customer = @account.all_users.where(:helpdesk_agent => false, :active => true, :deleted => false).where("email is not NULL").first
    if @customer.nil?
      @customer = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
                              :user_role => 3)
      @customer.save
    end
    @customer
  end

  def update_currency
    currency = Subscription::Currency.find_by_name("USD")
    if currency.blank?
      currency = Subscription::Currency.create({ :name => "USD", :billing_site => "freshpo-test", 
          :billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e", :exchange_rate => 1})
    end
    subscription = @account.subscription
    subscription.set_billing_params("USD")
    subscription.state.downcase!
    subscription.sneaky_save
  end

  def enable_feature(feature)
    @account.add_feature(feature)
    @account.make_current.reload
    yield
    @account.revoke_feature(:shared_ownership)
    @account.make_current.reload
  end

  def account_params
    domain_name = Faker::Lorem.words(1).first
    params_hash = {"callback"=>"jQuery15109332231594828528_1492670349192",
     "account"=>{"name"=>domain_name, "domain"=>domain_name}, 
     "utc_offset"=>"5.5",
     "user"=>{"email"=>Faker::Internet.email, "name"=>domain_name}
     # "_"=>"1492670471356", "action"=>"new_signup_free", "controller"=>"accounts"
    }
  end

end