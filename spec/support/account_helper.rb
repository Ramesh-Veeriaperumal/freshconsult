module AccountHelper
  include Redis::RedisKeys

  def create_test_account(name = "test_account", domain = "test@freshdesk.local")
    @acc = Account.first
    unless @acc.nil?
      @acc.make_current
      create_dummy_customer
      return @acc
    end
    ENV["SEED"]="002_subscription_plans"
    ENV["FIXTURE_PATH"] = "db/fixtures/global"
    SeedFu::PopulateSeed.populate
    ENV["SEED"] = nil
    ENV["FIXTURE_PATH"] = nil
    
    create_new_account
    update_currency
    @acc
  end

  def create_test_billing_acccount
    auto_increment_query = "ALTER TABLE shard_mappings AUTO_INCREMENT = #{Time.now.to_i}"
    ActiveRecord::Base.connection.execute(auto_increment_query)

    create_new_account("billingtest#{Time.now.to_i}", "sample+#{Time.now.to_i}@freshdesk.com")
  end

  def create_new_account(domain = "localhost", user_email = Helpdesk::EMAIL[:sample_email])
    signup = Signup.new(  
      :account_name => 'Test Account',
      :account_domain => domain,
      :locale => I18n.default_locale,
      :user_name => 'Support',
      :user_password => 'test',
      :user_password_confirmation => 'test', 
      :user_email => user_email,
      :user_helpdesk_agent => true
    )
    signup.save
    
    PopulateGlobalBlacklistIpsTable.create_default_record
    @acc = signup.account
    @acc.make_current
    create_dummy_customer
    @acc
  end

  def create_dummy_customer
    @customer = @acc.users.find(:all, :conditions => "helpdesk_agent = 0 and email IS NOT NULL and active = 1 and deleted = 0", :limit => 1).first

    if @customer.nil?
      @customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email, :user_role => 3)
      @customer.save
    end

    @customer
  end

  def clear_data
    #Account.destroy_all
    User.destroy_all
    Group.destroy_all
    Agent.destroy_all
    Helpdesk::Ticket.destroy_all
    AgentGroup.destroy_all
    Solution::Category.destroy_all
    Solution::Folder.destroy_all  
    Solution::Article.destroy_all  
  end

  def update_currency
    currency = Subscription::Currency.find_by_name("USD")
    if currency.blank?
      currency = Subscription::Currency.create({ :name => "USD", :billing_site => "freshpo-test", 
          :billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e", :exchange_rate => 1})
    end
    
    subscription = @acc.subscription
    subscription.set_billing_params("USD")
    subscription.save
  end

  def mue_key_state(account)
    $redis_others.sismember(USER_EMAIL_MIGRATED, account.id.to_s)
  end
  
  def enable_mue_key(account)
    $redis_others.sadd(USER_EMAIL_MIGRATED, account.id.to_s) unless $redis_others.sismember(USER_EMAIL_MIGRATED, account.id.to_s)
  end

  def disable_mue_key(account)
    $redis_others.srem(USER_EMAIL_MIGRATED, account.id.to_s) if $redis_others.sismember(USER_EMAIL_MIGRATED, account.id.to_s)
  end

  def restore_default_feature feature
    @account.features.send(feature).create unless @account.features_included?(feature.to_sym)
  end

  def portal_url
    portal    = @account.main_portal
    protocol  = portal.ssl_enabled? ? 'https://' : 'http://'
    return (protocol + portal.host)
  end

  def account_protocol
    portal    = @account.main_portal
    protocol  = portal.ssl_enabled? ? 'https://' : 'http://'
  end
  
end
