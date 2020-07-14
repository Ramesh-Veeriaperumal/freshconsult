module AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include CentralLib::Util

  def create_test_account(_name = 'test_account', _domain = 'test@freshdesk.local')
    subscription = Subscription.where("state != 'suspended'").first
    @account = Account.find_by_id(subscription.account_id) unless subscription.nil?
    if @account.nil?
      ENV['SEED'] = 'global/002_subscription_plans'
      ENV['FIXTURE_PATH'] = 'db/fixtures/global'
      SeedFu::PopulateSeed.populate
      ENV['SEED'] = nil
      ENV['FIXTURE_PATH'] = nil
      create_new_account
      update_currency
    else
      @account.make_current
    end
    create_dummy_customer
  end

  def create_new_account(domain = 'localhost', user_email = Helpdesk::EMAIL[:sample_email])
    Account.reset_current_account
    signup = Signup.new(
      account_name: 'Test Account',
      account_domain: domain,
      locale: I18n.default_locale,
      time_zone: 'Chennai',
      user_name: 'Support',
      user_password: 'test1234',
      user_password_confirmation: 'test1234',
      user_email: user_email,
      user_helpdesk_agent: true,
      new_plan_test: true
    )
    signup.save

    PopulateGlobalBlacklistIpsTable.create_default_record
    @account = signup.account.make_current
  end

  def create_sample_account(domain = 'localhost', user_email = Helpdesk::EMAIL[:sample_email])
    ENV['SEED'] = 'global/002_subscription_plans'
    ENV['FIXTURE_PATH'] = 'db/fixtures/global'
    SeedFu::PopulateSeed.populate
    ENV['SEED'] = nil
    ENV['FIXTURE_PATH'] = nil
    Account.reset_current_account
    signup = Signup.new(
      account_name: 'Test Account',
      account_domain: domain,
      locale: I18n.default_locale,
      time_zone: 'Chennai',
      user_name: 'Support',
      user_password: 'test1234',
      user_password_confirmation: 'test1234',
      user_email: user_email,
      user_helpdesk_agent: true,
      new_plan_test: true
    )
    signup.save!
    PopulateGlobalBlacklistIpsTable.create_default_record
    @account = signup.account.make_current
    update_currency
  end

  def disable_background_fixtures
    remove_others_redis_key(BACKGROUND_FIXTURES_ENABLED)
  end

  def enable_background_fixtures
    set_others_redis_key(BACKGROUND_FIXTURES_ENABLED, 1, nil)
  end

  def create_dummy_customer
    @customer = @account.all_users.where(helpdesk_agent: false, active: true, deleted: false).where('email is not NULL').first
    if @customer.nil?
      @customer = FactoryGirl.build(:user, account: @account, email: Faker::Internet.email,
                                           user_role: 3)
      @customer.save
    end
    @customer
  end

  def update_currency
    currency = Subscription::Currency.find_by_name('USD')
    if currency.blank?
      currency = Subscription::Currency.create(name: 'USD', billing_site: 'freshpo-test',
                                               billing_api_key: 'fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e', exchange_rate: 1)
    end
    subscription = @account.subscription
    subscription.set_billing_params('USD')
    subscription.state.downcase!
    subscription.sneaky_save
  end

  def enable_feature(feature)
    MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
    @account.add_feature(feature)
    @account.make_current.reload

    yield

    @account.reload
    @account.revoke_feature(feature)
    @account.make_current.reload
    MixpanelWrapper.unstub(:send_to_mixpanel)
  end

  def account_params
    domain_name = Faker::Lorem.words(1).first
    params_hash = { 'callback' => 'jQuery15109332231594828528_1492670349192',
                    'account' => { 'name' => domain_name, 'domain' => domain_name },
                    'utc_offset' => '5.5',
                    'user' => { 'email' => Faker::Internet.email, 'name' => domain_name } }
    # "_"=>"1492670471356", "action"=>"new_signup_free", "controller"=>"accounts"
  end

  def signup_params
    {
      'fs_cookie' => Faker::Lorem.characters(50),
      'signup_id' => Faker::Number.number(2)
    }
  end

  def account_params_without_domain(user_email)
    account_name = Faker::Lorem.word
    params_hash = { 'callback' => '',
                    'user' => { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' },
                    'account' => { account_name: account_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true },
                    'format' => 'json' }
  end

  def central_publish_account_post(account)
    portal_languages = []
    if account.account_additional_settings.present? && account.account_additional_settings.portal_languages.present?
      portal_languages = account.account_additional_settings.portal_languages
    end
    all_languages = if account.account_additional_settings.present? && account.account_additional_settings.supported_languages.present?
                      account.account_additional_settings.supported_languages + [account.main_portal.language]
                    else
                      [account.main_portal.language]
                    end
    all_languages = language_details(all_languages)
    {
      id: account.id,
      name: account.name,
      full_domain: account.full_domain,
      time_zone: account.time_zone,
      helpdesk_name: account.helpdesk_name,
      sso_enabled: account.sso_enabled,
      sso_options: account.sso_options,
      ssl_enabled: account.ssl_enabled,
      reputation: account.reputation,
      account_type: { id: account.account_type, name: Account::ACCOUNT_TYPES.key(account.account_type) },
      features: account.features_list,
      created_at: account.created_at.try(:utc).try(:iso8601),
      updated_at: account.updated_at.try(:utc).try(:iso8601),
      premium: account.premium,
      freshid_account_id: account.freshid_account_id,
      fs_cookie: account.fs_cookie,
      account_configuration: account.account_configuration.account_configuration_for_central,
      account_additional_settings: set_account_additional_settings(account),
      portal_languages: portal_languages,
      all_languages: all_languages
    }
  end

  def central_publish_rts_info(account)
    portal_languages = []
    portal_languages = account.account_additional_settings.portal_languages if account.account_additional_settings.present? && account.account_additional_settings.portal_languages.present?
    all_languages = if account.account_additional_settings.present? && account.account_additional_settings.supported_languages.present?
                      account.account_additional_settings.supported_languages + [account.main_portal.language]
                    else
                      [account.main_portal.language]
                    end
    all_languages = language_details(all_languages)
    {
      id: account.id,
      name: account.name,
      full_domain: account.full_domain,
      time_zone: account.time_zone,
      helpdesk_name: account.helpdesk_name,
      sso_enabled: account.sso_enabled,
      sso_options: account.sso_options,
      ssl_enabled: account.ssl_enabled,
      reputation: account.reputation,
      account_type: { id: account.account_type, name: Account::ACCOUNT_TYPES.key(account.account_type) },
      features: account.features_list,
      created_at: account.created_at.try(:utc).try(:iso8601),
      updated_at: account.updated_at.try(:utc).try(:iso8601),
      premium: account.premium,
      freshid_account_id: account.freshid_account_id,
      fs_cookie: account.fs_cookie,
      account_configuration: account.account_configuration.account_configuration_for_central,
      account_additional_settings: set_account_additional_settings(account),
      portal_languages: portal_languages,
      all_languages: all_languages,
      rts_account_id: account.account_additional_settings.rts_account_id,
      rts_account_secret: encrypt_for_central(account.account_additional_settings.rts_account_secret, 'account_additional_settings'),
      cipher_key: 'account_additional_settings'
    }
  end

  def central_publish_account_association_pattern(_expected_output = {})
    {
      subscription: Hash,
      organisation: nil,
      conversion_metric: Hash
    }
  end

  def central_publish_account_association_for_freshid_v2_pattern(_expected_output = {})
    {
      subscription: Hash,
      organisation: Hash
    }
  end

  def change_account_state(state, account)
    subscription = account.subscription
    subscription.state = state
    subscription.save!
  end

  def language_details(language_codes)
    language_details = []
    language_codes.each do |code|
      lang_obj = Language.find_by_code(code)
      language_details << lang_obj.as_json
    end
    language_details
  end

  def setup_multilingual(supported_languages = ['es', 'ru-RU'])
    @account.add_feature(:multi_language)
    @account.features.enable_multilingual.create
    @account.reload
    additional = @account.account_additional_settings
    additional.supported_languages = supported_languages
    additional.save
  end

  def setup_field_service_management_feature
    account_id = @account.id
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    Account.reset_current_account
    @account = Account.find(account_id)
    @account.make_current

    yield if block_given?
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    cleanup_fsm
  end

  def set_account_additional_settings(account)
    {}.tap do |settings|
      settings[:bundle_id] = account.omni_bundle_id
      settings[:bundle_name] = account.omni_bundle_name
    end
  end

  def freshid_organisation
    { 'id': '186333307716534827', 'name': 'afterschool-org', 'title': '', 'domain': 'test.freshworks.com', 'address': '', 'phone': '', 'locale': '', 'create_time': '2020-05-29T04:22:02Z', 'update_time': '2020-05-29T04:22:02Z', 'alternate_domain': '', 'time_zone': '' }
  end

  def freshid_user
    { 'first_name': 'Test', 'last_name': 'Test Last', 'email': 'test@gmail.com', 'phone': nil, 'job_title': '', 'company_name': '' }
  end
end
