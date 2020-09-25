module AccountHelper
  include Redis::RedisKeys

  def create_test_account(name = "test_account", domain = "test@freshdesk.local")
    subscription = Subscription.where("state != 'suspended'").first
    @acc = Account.find_by_id(subscription.account_id) unless subscription.nil?
    unless @acc.nil?
      @acc.make_current
      create_dummy_customer
      return @acc
    end
    ENV["SEED"]="global/002_subscription_plans"
    ENV["FIXTURE_PATH"] = "db/fixtures/global"
    SeedFu::PopulateSeed.populate
    ENV["SEED"] = nil
    ENV["FIXTURE_PATH"] = nil
    
    create_new_account
    update_currency
    @account = @acc
    @acc
  end

  def create_test_billing_acccount
    auto_increment_query = "ALTER TABLE shard_mappings AUTO_INCREMENT = #{Time.now.to_i}"
    ActiveRecord::Base.connection.execute(auto_increment_query)

    create_new_account("billingtest#{Time.now.to_i}", "sample+#{Time.now.to_i}@freshdesk.com")
  end

  def create_new_account(domain = "localhost", user_email = Helpdesk::EMAIL[:sample_email])
    Account.reset_current_account
    signup = Signup.new(  
      :account_name => 'Test Account',
      :account_domain => domain,
      :locale => I18n.default_locale,
      :time_zone => 'Chennai',
      :user_name => 'Support',
      :user_password => 'test',
      :user_password_confirmation => 'test', 
      :user_email => user_email,
      :user_helpdesk_agent => true
    )
    signup.save!
    
    PopulateGlobalBlacklistIpsTable.create_default_record
    @acc = signup.account
    @account = @acc
    @acc.make_current
    @acc.reload
    create_dummy_customer
    @acc
  end

  def create_dummy_customer
    @customer = @acc.all_users.where(:helpdesk_agent => false, :active => true, :deleted => false).where("email is not NULL").first

    if @customer.nil?
      @customer = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
      @customer.save_without_session_maintenance
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
    Solution::CategoryMeta.destroy_all
    Solution::Category.destroy_all
    Solution::FolderMeta.destroy_all
    Solution::Folder.destroy_all
    Solution::ArticleMeta.destroy_all
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
    subscription.state.downcase!
    subscription.sneaky_save
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

  def restore_default_setting(setting)
    @account.reload
    @account.enable_setting(setting.to_sym) unless @account.safe_send("#{setting}_enabled?")
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

  # Test cases use this to create a new acount.
  def create_new_test_account(name, domain, admin_email, admin_name)
    signup_params = { "callback"=>"", "account"=>{"name"=> name, "domain"=>domain}, 
        "utc_offset"=>"5.5", "user"=>{"email"=>admin_email, "name"=>admin_name} }
      
    Resque.inline = true 
    Billing::Subscription.any_instance.stubs(:create_subscription).returns(true)
    post :new_signup_free, signup_params
    Resque.inline = false
    Billing::Subscription.any_instance.unstub(:create_subscription)
  end

  def create_enable_multilingual_feature
    @account.reload
    supported_languages = pick_languages(@account.language, 3)
    @account.account_additional_settings.update_attributes({:supported_languages => supported_languages})
    @account.account_additional_settings.update_attributes(:additional_settings => {:portal_languages=> supported_languages.sample(2)})
    @account.features.enable_multilingual.create unless @account.features?(:enable_multilingual)
    find_account_and_make_current
    Sidekiq::Testing.inline! do
      Community::SolutionBinarizeSync.perform_async
    end
  end

  def find_account_and_make_current
    @account = Account.find(@account.id).make_current
  end

  def destroy_enable_multilingual_feature
    @account.account_additional_settings.update_attributes({:supported_languages => []})
    @account.features.enable_multilingual.destroy if @account.features?(:enable_multilingual)
    @account.reload
  end

  def pick_a_language
    (Language.all_codes.reject{ |l| l == @account.language }).sample.dup
  end

  def pick_languages(primary_lang, n)
    (Language.all_codes.map{ |lang| lang.dup }.reject{ |l| (l == @account.language || l == primary_lang) }).sample(n)
  end

  def pick_a_unsupported_language
    (Language.all_codes - @account.all_languages).sample.dup
  end

  def enable_multilingual
    create_enable_multilingual_feature
    @account.features.multi_language.create
    @account.reload
  end
  
end
