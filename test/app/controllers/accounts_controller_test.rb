require_relative '../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'
class AccountsControllerTest < ActionController::TestCase
  include Redis::RedisKeys
  include Redis::OthersRedis
  include UsersHelper
  include AccountTestHelper
  include HelpWidgetsTestHelper

  def stub_signup_calls
    Signup.any_instance.stubs(:save).returns(true)
    AccountInfoToDynamo.stubs(:perform_async).returns(true)
    Account.any_instance.stubs(:mark_new_account_setup_and_save).returns(true)
    Account.any_instance.stubs(:launched?).returns(true)
    Account.any_instance.stubs(:anonymous_account?).returns(false)
    Account.any_instance.stubs(:fluffy_email_signup_enabled?).returns(false)
    User.any_instance.stubs(:deliver_admin_activation).returns(true)
    User.any_instance.stubs(:perishable_token).returns(Faker::Number.number(5))
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
  end

  def unstub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountInfoToDynamo.unstub(:perform_async)
    Account.any_instance.unstub(:mark_new_account_setup_and_save)
    Account.any_instance.unstub(:launched?)
    Account.any_instance.unstub(:anonymous_account?)
    Account.any_instance.unstub(:fluffy_email_signup_enabled?)
    User.any_instance.unstub(:deliver_admin_activation)
    User.any_instance.unstub(:perishable_token)
    User.any_instance.unstub(:reset_perishable_token!)
  end

  def current_account
    Account.first || create_test_account
  end

  def test_new_signup
    stub_signup_calls
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    Account.stubs(:current).returns(Account.first)
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 200
  ensure
    unstub_signup_calls
    Account.unstub(:current)
  end

  def test_default_account_settings_when_new_signup_with_feature_based_settings_enabled
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    landing_url = Faker::Internet.url
    user_name = Faker::Name.name
    session = { current_session: { referrer: Faker::Lorem.word, url: landing_url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_not_nil resp['account_id'], resp
    account = Account.find(resp['account_id'])
    assert account.has_feature?(:untitled_setting_3)
    assert account.has_feature?(:untitled_setting_4)
    assert_equal account.has_feature?(:untitled_setting_1), false
  ensure
    Account.find(resp['account_id']).destroy if resp['account_id'].present?
    unstub_signup_calls    
  end

  def test_default_account_settings_when_new_signup_with_feature_based_settings_disabled
    stub_signup_calls
    Account.any_instance.stubs(:launched?).with(:feature_based_settings).returns(false)
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    landing_url = Faker::Internet.url
    user_name = Faker::Name.name
    session = { current_session: { referrer: Faker::Lorem.word, url: landing_url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_not_nil resp['account_id'], resp
    account = Account.find(resp['account_id'])
    assert_equal account.has_feature?(:untitled_setting_3), false
    assert_equal account.has_feature?(:untitled_setting_4), false
    assert_equal account.has_feature?(:untitled_setting_1), false
  ensure
    Account.find(resp['account_id']).destroy if resp['account_id'].present?
    unstub_signup_calls    
  end

  def test_new_signup_with_precreated_account
    populate_plans
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
    Subscription.any_instance.stubs(:add_to_billing).returns(true)
    PrecreatedSignup.any_instance.stubs(:aloha_signup).returns(true)
    PrecreatedSignup.any_instance.stubs(:freshid_v2_signup_allowed?).returns(true)
    PrecreatedSignup.any_instance.stubs(:organisation).returns(freshid_organisation)
    PrecreatedSignup.any_instance.stubs(:freshid_user).returns(freshid_user)
    Account.any_instance.stubs(:sync_user_info_from_freshid_v2!).returns(true)
    User.any_instance.stubs(:sync_profile_from_freshid).returns(true)
    AccountCreation::PrecreateAccounts.new.perform(precreate_account_count: 1, shard_name: 'shard_1')
    @controller.stubs(:redis_key_exists?).with('PRECREATE_ACCOUNT_ENABLED').returns(true)
    precreated_account_id = get_others_redis_list(format(PRECREATED_ACCOUNTS_SHARD, current_shard: 'shard_1'), 0, 0)
    stub_signup_calls
    user_email = 'fsmonsignup@gleason.com'
    user_name = Faker::Name.name
    session = { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: Faker::Lorem.word, account_domain: Faker::Lorem.word, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_equal resp['account_id'], precreated_account_id[0].to_i
  ensure
    unstub_signup_calls
    @controller.unstub(:redis_key_exists?)
    Account.unstub(:current)
    AccountConfiguration.any_instance.unstub(:update_billing)
    Subscription.any_instance.unstub(:add_to_billing)
    PrecreatedSignup.any_instance.unstub(:aloha_signup)
    PrecreatedSignup.any_instance.unstub(:freshid_v2_signup_allowed?)
    PrecreatedSignup.any_instance.unstub(:organisation)
    PrecreatedSignup.any_instance.unstub(:freshid_user)
    Account.any_instance.unstub(:sync_user_info_from_freshid_v2!)
    User.any_instance.unstub(:sync_profile_from_freshid)
  end

  def test_new_signup_with_exception_in_precreated_account
    populate_plans
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
    Subscription.any_instance.stubs(:add_to_billing).returns(true)
    AccountCreation::PrecreateAccounts.new.perform(precreate_account_count: 1, shard_name: 'shard_1')
    @controller.stubs(:redis_key_exists?).with('PRECREATE_ACCOUNT_ENABLED').returns(true)
    precreated_account_id = get_others_redis_list(format(PRECREATED_ACCOUNTS_SHARD, current_shard: 'shard_1'), 0, 0)
    PrecreatedSignup.any_instance.stubs(:save!).raises(StandardError)
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    user_email = 'fsmonsignup@gleason.com'
    user_name = Faker::Name.name
    session = { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: Faker::Lorem.word, account_domain: Faker::Lorem.word, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_not_equal resp['account_id'], precreated_account_id[0].to_i
  ensure
    unstub_signup_calls
    @controller.unstub(:redis_key_exists?)
    Account.unstub(:current)
    AccountConfiguration.any_instance.unstub(:update_billing)
    Subscription.any_instance.unstub(:add_to_billing)
    PrecreatedSignup.any_instance.unstub(:save!)
  end

  def test_twitter_requester_fields_creation_on_signup
    Freemail.stubs(:free?).returns(false)
    subdomain = Account::RESERVED_DOMAINS.first
    user_email = "#{Faker::Lorem.word}#{rand(1_000)}@#{subdomain}.com"
    params = account_params_without_domain(user_email)
    get :new_signup_free, params
    Account.stubs(:current).returns(Account.find_by_id(JSON.parse(response.body)['account_id']))
    assert_response 200
    twitter_requester_fields = ['twitter_profile_status', 'twitter_followers_count']
    assert_equal Account.current.contact_fields.collect(&:name) & twitter_requester_fields, twitter_requester_fields
  ensure
    Account.unstub(:current)
  end

  def test_fsm_enabled_on_signup
    stub_signup_calls
    Account.any_instance.stubs(:ticket_field_revamp_enabled?).returns(false)
    Account.any_instance.stubs(:id_for_choices_write_enabled?).returns(false)
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'fsmonsignup@gleason.com'
    landing_url = Faker::Internet.url
    user_name = Faker::Name.name
    @controller.stubs(:get_all_members_in_a_redis_set).returns([landing_url])
    session = { current_session: { referrer: Faker::Lorem.word, url: landing_url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_not_nil resp['account_id'], resp
    account = Account.find(resp['account_id'])
    assert_equal true, account.field_service_management_toggle_enabled?
    assert_equal true, account.field_service_management_enabled?
    service_group_type = GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)
    service_group_count_after_fsm = account.groups.where('group_type' => service_group_type).count
    service_ticket_count_after_fsm = account.tickets.where("ticket_type = 'Service Task'").count
    assert_equal 3, service_group_count_after_fsm
    assert_equal 3, service_ticket_count_after_fsm
  ensure
    unstub_signup_calls
    Account.any_instance.unstub(:ticket_field_revamp_enabled?)
    Account.any_instance.unstub(:id_for_choices_write_enabled?)
    @controller.unstub(:get_all_members_in_a_redis_set)
  end

  def test_fsm_not_enabled_on_signup
    stub_signup_calls
    Account.any_instance.stubs(:ticket_field_revamp_enabled?).returns(false)
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = Faker::Internet.url
    user_name = Faker::Name.name
    @controller.stubs(:get_all_members_in_a_redis_set).returns(['http:://fake.google.com'])
    session = { current_session: { referrer: Faker::Lorem.word, url: landing_url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: 'en', browser: {}, time: {} }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    assert_not_nil resp['account_id'], resp
    account = Account.find(resp['account_id'])
    assert_equal false, account.field_service_management_enabled?
    service_group_type = GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)
    service_group_count_after_fsm = account.groups.where('group_type' => service_group_type).count
    service_ticket_count_after_fsm = account.tickets.where("ticket_type = 'Service Task'").count
    assert_equal 0, service_group_count_after_fsm
    assert_equal 0, service_ticket_count_after_fsm
  ensure
    unstub_signup_calls
    @controller.unstub(:get_all_members_in_a_redis_set)
  end

  def test_signup_with_session_params
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    account_name = Faker::Lorem.word
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 200
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_new_signup_with_html_format
    stub_signup_calls
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    Account.stubs(:current).returns(Account.first)
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'html'
    assert_response 200
  ensure
    unstub_signup_calls
    Account.unstub(:current)
  end

  def test_new_signup_with_nmobile_format
    stub_signup_calls
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    Account.stubs(:current).returns(Account.first)
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'nmobile'
    assert_response 200
  ensure
    unstub_signup_calls
    Account.unstub(:current)
  end

  def test_email_signup
    stub_signup_calls
    Rails.env.stubs(:staging?).returns(true)
    Subscriptions::AddLead.stubs(:perform_at).returns(true)
    CRMApp::Freshsales::Signup.stubs(:perform_at).returns(true)
    Account.any_instance.stubs(:launched?).returns(false)
    Account.stubs(:current).returns(Account.first)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    get :email_signup, action: 'email_signup', callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 200
    assert JSON.parse(response.body)['url'].include?('signup_complete'), 'expecting signup_complete url'
  ensure
    unstub_signup_calls
    Rails.env.unstub(:staging?)
    Subscriptions::AddLead.unstub(:perform_at)
    CRMApp::Freshsales::Signup.unstub(:perform_at)
    Account.any_instance.unstub(:launched?)
    Account.unstub(:current)
  end

  def test_email_signup_errors_when_url_is_passed
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    get :email_signup, callback: '', user: { first_name: Faker::Internet.url, last_name: Faker::Internet.url, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 422

    get :new_signup_free, callback: '', user: { first_name: Faker::Internet.url, last_name: Faker::Internet.url, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 422
  end

  def test_new_signup_save_failure
    Signup.any_instance.stubs(:save).returns(false)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['success'], false
  ensure
    Signup.any_instance.unstub(:save)
  end

  def test_email_signup_save_failure
    Signup.any_instance.stubs(:save).returns(false)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    get :email_signup, action: 'email_signup', callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['success'], false
  ensure
    Signup.any_instance.unstub(:save)
  end

  def test_signup_with_invalid_email
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Lorem.word
    get :email_signup, action: 'email_signup', callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 422
  end

  def test_signup_when_email_has_many_account_associations
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    fake_account = []
    11.times do
      fake_account << Faker::Lorem.word
    end
    AdminEmail::AssociatedAccounts.stubs(:find).returns(fake_account)
    get :email_signup, action: 'email_signup', callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 429
  ensure
    AdminEmail::AssociatedAccounts.unstub(:find)
  end

  def test_email_for_increasing_signup_count
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    fake_account = []
    11.times do
      fake_account << Faker::Lorem.word
    end
    AdminEmail::AssociatedAccounts.stubs(:find).returns(fake_account)
    add_member_to_redis_set(INCREASE_DOMAIN_FOR_EMAILS, user_email)
    get :email_signup, action: 'email_signup', callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    assert_response 200
    ensure
      AdminEmail::AssociatedAccounts.unstub(:find)
      remove_member_from_redis_set(INCREASE_DOMAIN_FOR_EMAILS, user_email)
  end

  def test_domain_existence
    get :check_domain, domain: "#{Faker::Lorem.word}.com", callback: '', format: 'json'
    parsed_response = parse_response response.body
    assert_response 200
    assert parsed_response['account_name']
  end

  def test_domain_validation_performs_correctly_for_invalid_domain
    get :validate_domain, company_domain: 'test.a.http://af.com', format: 'json'
    parsed_response = parse_response response.body
    assert_response 422
    assert_equal parsed_response['success'], false
  end

  def test_domain_validation_performs_correctly_for_valid_domain
    get :validate_domain, company_domain: 'test06032019', format: 'json'
    parsed_response = parse_response response.body
    assert_response 200
    assert parsed_response['success']
  end

  def test_signup_with_reserved_keyword_in_email
    Freemail.stubs(:free?).returns(true)
    subdomain = Account::RESERVED_DOMAINS.first
    user_email = "#{subdomain}@freshdesk.com"
    params = account_params_without_domain(user_email)
    get :new_signup_free, params
    full_domain = Regexp.new("#{subdomain.downcase.gsub(/[^0-9a-z]/i, '')}(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')}).freshpo.com")
    response_url = parse_response(@response.body)['url'].split('/')[2]
    assert_match(full_domain, response_url)
    assert_response 200
  ensure
    Freemail.unstub(:free?)
  end

  def test_signup_with_reserved_keyword_in_email_domain
    Freemail.stubs(:free?).returns(false)
    subdomain = Account::RESERVED_DOMAINS.first
    user_email = "#{Faker::Lorem.word}#{rand(1_000)}@#{subdomain}.com"
    params = account_params_without_domain(user_email)
    get :new_signup_free, params
    full_domain = Regexp.new("#{subdomain.downcase.gsub(/[^0-9a-z]/i, '')}(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')}).freshpo.com")
    response_url = parse_response(@response.body)['url'].split('/')[2]
    assert_match(full_domain, response_url)
    assert_response 200
  ensure
    Freemail.unstub(:free?)
  end

  def test_edit
    get :edit
    assert_response 200
  end

  def test_signup_with_empty_domain
    get :signup_validate_domain, domain: '', format: 'json'
    assert_response 400
  end

  def test_signup_domain_validation
    get :signup_validate_domain, domain: Faker::Internet.domain_word, format: 'json'
    assert_response 200
  end

  def test_edit_domain
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    UserEmail.any_instance.stubs(:update_attributes).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    get :edit_domain, perishable_token: Account.first.users.first.perishable_token
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    UserEmail.any_instance.unstub(:update_attributes)
    UserSession.any_instance.unstub(:save)
  end

  def test_edit_domain_without_session
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(false)
    get :edit_domain, perishable_token: Account.first.users.first.perishable_token
    assert_response 302
    assert_includes response.redirect_url, support_login_url
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    UserSession.any_instance.unstub(:save)
  end

  def test_edit_domain_with_invalid_user
    User.any_instance.stubs(:privilege?).returns(false)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    get :edit_domain, perishable_token: Account.first.users.first.perishable_token
    assert_response 302
    assert_includes response.redirect_url, support_login_path
  ensure
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:freshid_enabled?)
  end

  def test_update_domain
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:update_default_domain_and_email_config).returns(true)
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
    get :update_domain, company_domain: Faker::Lorem.word
    assert_response 200
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:update_default_domain_and_email_config)
    User.any_instance.unstub(:reset_perishable_token!)
  end

  def test_update_domain_with_domain_update_failure
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Account.any_instance.stubs(:update_default_domain_and_email_config).returns(false)
    get :update_domain, company_domain: Faker::Internet.domain_word
    parsed_response = parse_response response.body
    assert_equal parsed_response['success'], false
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:update_default_domain_and_email_config)
  end

  def test_update_domain_with_freshid_disabled_and_activation_job_present_html_format
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Account.any_instance.stubs(:update_default_domain_and_email_config).returns(true)
    Account.any_instance.stubs(:kill_account_activation_email_job).returns(true)
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
    Sidekiq::ScheduledSet.any_instance.stubs(:find_job).returns([Faker::Lorem.word])
    get :update_domain, company_domain: Faker::Lorem.word, support_email: Faker::Lorem.word, format: 'html'
    assert_response 200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:update_default_domain_and_email_config)
    Account.any_instance.unstub(:kill_account_activation_email_job)
    User.any_instance.unstub(:reset_perishable_token!)
    Sidekiq::ScheduledSet.any_instance.unstub(:find_job)
  end

  def test_update_domain_with_freshid_disabled_and_activation_job_present_json_format
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Account.any_instance.stubs(:update_default_domain_and_email_config).returns(true)
    Account.any_instance.stubs(:kill_account_activation_email_job).returns(true)
    User.any_instance.stubs(:reset_perishable_token!).returns(true)
    Sidekiq::ScheduledSet.any_instance.stubs(:find_job).returns([Faker::Lorem.word])
    get :update_domain, company_domain: Faker::Internet.domain_word, format: 'json'
    assert_response 200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:update_default_domain_and_email_config)
    Account.any_instance.unstub(:kill_account_activation_email_job)
    User.any_instance.unstub(:reset_perishable_token!)
    Sidekiq::ScheduledSet.any_instance.unstub(:find_job)
  end

  def test_update_domain_without_response_params
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    get :update_domain, company_domain: Faker::Lorem.word
    assert_response 302
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
  end

  def test_update_domain_with_freshid_disabled_and_without_activation_job
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Sidekiq::ScheduledSet.any_instance.stubs(:find_job).returns([])
    get :update_domain, company_domain: Faker::Lorem.word, format: 'html'
    assert_response 302

    get :update_domain, company_domain: Faker::Lorem.word, format: 'json'
    assert_response 408
  ensure
    Account.any_instance.unstub(:freshid_enabled?)
    Sidekiq::ScheduledSet.any_instance.unstub(:find_job)
  end

  def test_create
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_create_with_session_params
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_create_with_session_params_for_phone
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: { is_phone: true }, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_create_with_session_params_for_mobile_device
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: { is_mobile: true }, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_create_with_session_params_for_tablet_device
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: { is_tablet: true }, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_create_with_save_failure
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(false)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_update
    Account.any_instance.stubs(:save).returns(true)
    Account.any_instance.stubs(:update_attributes!).returns(true)
    Account.any_instance.stubs(:clear_association_cache).returns(true)
    Account.any_instance.stubs(:reset_feature).returns(true)
    Account.any_instance.stubs(:set_feature).returns(true)
    Account.any_instance.stubs(:twitter_signin_enabled?).returns(true)
    Account.any_instance.stubs(:restricted_helpdesk?).returns(false)
    Account.any_instance.stubs(:custom_domain_enabled?).returns(false)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    put :update, id: Account.first.id, account: { account_additional_settings_attributes: {}, features: { 'reverse_notes' => true, 'forums' => true }, main_portal_attributes: {}, permissible_domains: [], bitmap_features: { 'split_tickets' => '0', 'add_watcher' => '1' } }, enable_restricted_helpdesk: 'create'
    assert_response 302
  ensure
    Account.any_instance.unstub(:save)
    Account.any_instance.unstub(:update_attributes!)
    Account.any_instance.unstub(:clear_association_cache)
    Account.any_instance.unstub(:reset_feature)
    Account.any_instance.unstub(:set_feature)
    Account.any_instance.unstub(:twitter_signin_enabled?)
    Account.any_instance.unstub(:restricted_helpdesk?)
    Account.any_instance.unstub(:custom_domain_enabled?)
  end

  def test_update_with_save_failure
    Account.any_instance.stubs(:save).returns(false)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    put :update, id: Account.first.id, account: { account_additional_settings_attributes: {}, features: { 'reverse_notes' => '0', 'forums' => '1' }, main_portal_attributes: {}, permissible_domains: [] }
    assert_response 404
  ensure
    Account.any_instance.unstub(:save)
  end

  def test_rebrand
    Portal.any_instance.stubs(:update_attributes).returns(true)
    put :rebrand, account: { main_portal_attributes: {} }
    assert_response 302
  ensure
    Portal.any_instance.unstub(:update_attributes)
  end

  def test_cancel
    Billing::Subscription.any_instance.stubs(:cancel_subscription).returns(true)
    Account.any_instance.stubs(:free_or_active_account?).returns(true)
    Account.any_instance.stubs(:add_churn).returns(true)
    Account.any_instance.stubs(:schedule_cleanup).returns(true)
    Account.any_instance.stubs(:update_crm).returns(true)
    Account.any_instance.stubs(:send_account_deleted_email).returns(true)
    Account.any_instance.stubs(:create_deleted_customers_info).returns(true)
    Account.any_instance.stubs(:clear_account_data).returns(true)
    post :cancel, confirm: true
    assert_response 302

    Account.any_instance.stubs(:active?).returns(false)
    post :cancel, confirm: true
    assert_response 302
  ensure
    Billing::Subscription.any_instance.unstub(:cancel_subscription)
    Account.any_instance.unstub(:free_or_active_account?)
    Account.any_instance.unstub(:add_churn)
    Account.any_instance.unstub(:schedule_cleanup)
    Account.any_instance.unstub(:update_crm)
    Account.any_instance.unstub(:send_account_deleted_email)
    Account.any_instance.unstub(:create_deleted_customers_info)
    Account.any_instance.unstub(:clear_account_data)
  end

  def test_dashboard
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    get :dashboard
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
  end

  def test_update_languages
    Account.any_instance.stubs(:save).returns(true)
    Account.any_instance.stubs(:features_included?).returns(false)
    Account.any_instance.stubs(:supported_languages).returns(['en', 'ca', 'et'])
    put :update_languages, id: Account.first.id, account: { account_additional_settings_attributes: { supported_languages: ['ar', 'ca', 'et'] }, main_portal_attributes: {} }
    assert_response 302
    assert_includes response.redirect_url, edit_account_path
  ensure
    Account.any_instance.unstub(:save)
    Account.any_instance.unstub(:features_included?)
    Account.any_instance.unstub(:supported_languages)
  end

  def test_update_languages_redirects_when_mail_portal_language_present
    put :update_languages, id: Account.first.id, account: { account_additional_settings_attributes: { supported_languages: ['en', 'ar', 'ca', 'et'] }, main_portal_attributes: {} }
    assert_response 302
    assert_includes response.redirect_url, manage_languages_path
  end

  def test_update_languages_redirects_during_save_failure
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    Account.any_instance.stubs(:save).returns(false)
    put :update_languages, id: Account.first.id, account: { account_additional_settings_attributes: { supported_languages: ['ar', 'ca', 'et'] }, main_portal_attributes: {} }
    assert_response 200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
    Account.any_instance.unstub(:save)
  end

  def test_remove_branding_non_sprout_or_trail_plan
    Subscription.any_instance.stubs(:trial_or_sprout_plan?).returns(false)
    put :update, id: Account.first.id, account: { helpdesk_name: 'Test Account', account_additional_settings_attributes: { date_format: 1, id: 1, supported_languages: [] }, time_zone: 'Casablanca', ticket_display_id: 4, features: { forums: 1 }, bitmap_features: { forums: '', branding: 0 }, main_portal_attributes: { id: 1 }, permissible_domains: '' }
    assert_response 302
    refute Account.current.has_feature?(:branding)
  ensure
    Subscription.any_instance.unstub(:trial_or_sprout_plan?)
  end

  def test_branding_off_update_help_widget
    Subscription.any_instance.stubs(:trial_or_sprout_plan?).returns(false)
    help_widget = create_widget
    HelpWidget::UploadConfig.jobs.clear
    Account.any_instance.stubs(:help_widget_enabled?).returns(true)
    put :update, id: Account.first.id, account: { helpdesk_name: 'Test Account', account_additional_settings_attributes: { date_format: 1, id: 1, supported_languages: [] }, time_zone: 'Casablanca', ticket_display_id: 4, features: { forums: 1 }, bitmap_features: { forums: '', branding: 0 }, main_portal_attributes: { id: 1 }, permissible_domains: '' }
    widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
    assert_include widget_json_upload_ids, help_widget.id
    refute Account.current.has_feature?(:branding)
    assert help_widget.as_api_response(:s3_format)[:settings][:appearance][:remove_freshworks_branding]
  ensure
    Subscription.unstub(:trial_or_sprout_plan?)
    Account.any_instance.unstub(:help_widget_enabled?)
  end

  def test_branding_on_update_help_widget
    Subscription.any_instance.stubs(:trial_or_sprout_plan?).returns(false)
    help_widget = create_widget
    HelpWidget::UploadConfig.jobs.clear
    Account.any_instance.stubs(:help_widget_enabled?).returns(true)
    put :update, id: Account.first.id, account: { helpdesk_name: 'Test Account', account_additional_settings_attributes: { date_format: 1, id: 1, supported_languages: [] }, time_zone: 'Casablanca', ticket_display_id: 4, features: { forums: 1 }, bitmap_features: { forums: '', branding: 1 }, main_portal_attributes: { id: 1 }, permissible_domains: '' }
    widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
    assert_include widget_json_upload_ids, help_widget.id
    assert Account.current.has_feature?(:branding)
    refute help_widget.as_api_response(:s3_format)[:settings][:appearance][:remove_freshworks_branding]
  ensure
    Subscription.any_instance.unstub(:trial_or_sprout_plan?)
    Account.any_instance.unstub(:help_widget_enabled?)
    Account.current.revoke_feature(:branding)
  end

  def test_branding_without_help_widget_feature
    Subscription.any_instance.stubs(:trial_or_sprout_plan?).returns(false)
    create_widget
    HelpWidget::UploadConfig.jobs.clear
    Account.any_instance.stubs(:help_widget_enabled?).returns(false)
    put :update, id: Account.first.id, account: { helpdesk_name: 'Test Account', account_additional_settings_attributes: { date_format: 1, id: 1, supported_languages: [] }, time_zone: 'Casablanca', ticket_display_id: 4, features: { forums: 1 }, bitmap_features: { forums: '', branding: 1 }, main_portal_attributes: { id: 1 }, permissible_domains: '' }
    assert Account.current.has_feature?(:branding)
    widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
    assert_empty HelpWidget::UploadConfig.jobs
  ensure
    Subscription.any_instance.unstub(:trial_or_sprout_plan?)
    Account.any_instance.unstub(:help_widget_enabled?)
    Account.current.revoke_feature(:branding)
  end

  def test_portal_logo_deletion
    Portal.any_instance.stubs(:logo).returns(Helpdesk::Attachment.new)
    Helpdesk::Attachment.any_instance.stubs(:destroy).returns(true)
    Portal.any_instance.stubs(:save).returns(true)
    delete :delete_logo, format: 'html'
    assert_response 302

    delete :delete_logo, format: 'js'
    assert_response 200
  ensure
    Portal.any_instance.unstub(:logo)
    Helpdesk::Attachment.any_instance.unstub(:destroy)
    Portal.any_instance.unstub(:save)
  end

  def test_account_favicon_deletion
    Portal.any_instance.stubs(:fav_icon).returns(Helpdesk::Attachment.new)
    Helpdesk::Attachment.any_instance.stubs(:destroy).returns(true)
    Portal.any_instance.stubs(:save).returns(true)
    delete :delete_favicon, format: 'html'
    assert_response 302

    delete :delete_favicon, format: 'js'
    assert_response 200
  ensure
    Portal.any_instance.unstub(:fav_icon)
    Helpdesk::Attachment.any_instance.unstub(:destroy)
    Portal.any_instance.unstub(:save)
  end

  def test_account_create_raises_exception_for_invalid_params
    Account.any_instance.stubs(:needs_payment_info?).returns(true)
    Account.any_instance.stubs(:save).returns(true)
    user_email = Faker::Internet.email
    get :create, plan: 'Forest Jan 17', session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: { is_phone: true }, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 302
  ensure
    Account.any_instance.unstub(:needs_payment_info?)
    Account.any_instance.unstub(:save)
  end

  def test_primary_email_and_portal_build
    Account.any_instance.stubs(:build_primary_email_config).returns(true)
    Account.any_instance.stubs(:build_main_portal).returns(true)
    @controller.instance_variable_set(:@account, Account.first)
    @controller.safe_send(:build_primary_email_and_portal)
    assert @controller.instance_variable_get(:@account).primary_email_config.active
    assert @controller.safe_send(:authorized?)
    assert_equal @controller.safe_send(:redirect_url), action: 'show'
  ensure
    Account.any_instance.unstub(:build_primary_email_config)
    Account.any_instance.unstub(:build_main_portal)
  end

  def test_primary_email_and_portal_build_with_exception
    I18n.stubs(:available_locales).raises(StandardError)
    Account.any_instance.stubs(:build_primary_email_config).returns(true)
    Account.any_instance.stubs(:build_main_portal).returns(true)
    @controller.instance_variable_set(:@account, Account.first)
    @controller.safe_send(:build_primary_email_and_portal)
    assert @controller.instance_variable_get(:@account).primary_email_config.active
  ensure
    I18n.unstub(:available_locales)
    Account.any_instance.unstub(:build_primary_email_config)
    Account.any_instance.unstub(:build_main_portal)
  end

  def test_primary_email_and_portal_build_with_falcon_portal_theme_enabled
    Account.any_instance.stubs(:falcon_portal_theme_enabled?).returns(true)
    Account.any_instance.stubs(:build_primary_email_config).returns(true)
    Account.any_instance.stubs(:build_main_portal).returns(true)
    @controller.instance_variable_set(:@account, Account.first)
    @controller.safe_send(:build_primary_email_and_portal)
    assert @controller.instance_variable_get(:@account).primary_email_config.active
  ensure
    Account.any_instance.unstub(:falcon_portal_theme_enabled)
    Account.any_instance.unstub(:build_primary_email_config)
    Account.any_instance.unstub(:build_main_portal)
  end

  def test_correct_account_returns_for_valid_sub_domain
    @controller.params = { account: { sub_domain: 'localhost' } }
    assert_nil @controller.instance_variable_get(:@account)
    value = @controller.safe_send(:get_account_for_sub_domain)
    assert_equal @controller.instance_variable_get(:@account), Account.first
  end

  def test_anonymous_signup
    Account.any_instance.stubs(:anonymous_account?).returns(true)
    anonymous_signup_key = ANONYMOUS_ACCOUNT_SIGNUP_ENABLED
    set_others_redis_key(anonymous_signup_key, true)
    Account.any_instance.expects(:add_to_billing).never
    Account.any_instance.expects(:enable_fresh_connect).never
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.env['HTTP_ACCEPT'] = 'application/json'
    params = signup_params.symbolize_keys!
    post :anonymous_signup, params
    assert_response 200
    account = Account.last
    assert_equal account.anonymous_account?, true
    assert_equal account.admin_first_name, 'Demo'
    assert_equal account.admin_last_name, 'Account'
    assert_match(/freshdeskdemo[0-9]{13}@example.com/, account.admin_email)
    assert_match(/demo(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')})?[0-9]{13}.freshpo.com/, account.full_domain)
    assert_not_nil account.id
    key = format(ACCOUNT_SIGN_UP_PARAMS, account_id: account.id)
    value = JSON.parse(get_others_redis_key(key)).symbolize_keys!
    assert_equal value[:fs_cookie], params[:fs_cookie]
    assert_equal value[:signup_id], params[:signup_id]
  ensure
    Account.any_instance.unstub(:anonymous_account?)
    remove_others_redis_key(anonymous_signup_key)
    account.destroy if account.present?
  end

  def test_new_signup_with_freshdesk_brand_website_referrer
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://freshdesk.com/pricing'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/signup'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert account.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle]
    assert_equal account.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle], true
  ensure
    unstub_signup_calls
  end

  def test_new_signup_without_freshdesk_brand_website_referrer
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://freshdesk.com/demo'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/signup'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert_nil account.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle]
  ensure
    unstub_signup_calls
  end

  def test_new_signup_with_freshsales_as_referrer
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    Signup.any_instance.stubs(:aloha_signup).returns(true)
    Signup.any_instance.stubs(:freshid_v2_signup_allowed?).returns(true)
    Signup.any_instance.stubs(:organisation).returns(freshid_organisation)
    Signup.any_instance.stubs(:freshid_user).returns(freshid_user)
    Account.any_instance.stubs(:sync_user_info_from_freshid_v2!).returns(true)
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://freshdesk.com/pricing'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/signup'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    misc_info = { referring_product: 'freshsales' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, misc: misc_info, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert account.account_additional_settings.additional_settings[:onboarding_version]
    assert_equal account.account_additional_settings.additional_settings[:onboarding_version], 'freshsales_freshdesk_onboarding'
    assert_equal account.subscription.fetch_fdfs_discount_coupon, SubscriptionConstants::FDFSBUNDLE
  ensure
    unstub_signup_calls
    Signup.any_instance.unstub(:aloha_signup)
    Signup.any_instance.unstub(:freshid_v2_signup_allowed?)
    Signup.any_instance.unstub(:organisation)
    Signup.any_instance.unstub(:freshid_user)
    Account.any_instance.unstub(:sync_user_info_from_freshid_v2!)
  end

  def test_anonymous_signup_without_redis_enabled
    anonymous_signup_key = ANONYMOUS_ACCOUNT_SIGNUP_ENABLED
    remove_others_redis_key(anonymous_signup_key)
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.env['HTTP_ACCEPT'] = 'application/json'
    post :anonymous_signup
    assert_response 403
  end

  def test_anonymous_signup_complete_with_active_freshid_agent
    user = add_test_agent(current_account)
    User.any_instance.stubs(:active_freshid_agent?).returns(true)
    UserSession.any_instance.stubs(:record).returns(user)
    get :anonymous_signup_complete, account_id: Account.first.id
    assert_response 302
    assert_includes CGI.unescape(response.redirect_url), "support/login?new_account_signup=true&signup_email=#{user.email}"
  ensure
    User.any_instance.unstub(:active_freshid_agent?)
    UserSession.any_instance.unstub(:record)
  end

  def test_anonymous_signup_complete_with_default_login
    user = nil
    UserSession.any_instance.stubs(:record).returns(user)
    get :anonymous_signup_complete, account_id: Account.first.id
    assert_response 302
    assert_includes response.redirect_url, '/login'
  ensure
    UserSession.any_instance.unstub(:record)
  end

  def test_anonymous_signup_complete_for_new_agent
    user = add_test_agent(current_account)
    get :anonymous_signup_complete, account_id: Account.first.id
    assert_response 302
    assert_includes response.redirect_url, '/a/getstarted'
  end

  def test_lead_updated_from_freshmarketer_during_account_deletion_without_associated_accounts
    WebMock.allow_net_connect!
    ThirdCRM.any_instance.expects(:update_lead).once
    AdminEmail::AssociatedAccounts.stubs(:find).returns(nil)
    Account.any_instance.stubs(:admin_email).returns(Faker::Internet.email)
    create_sample_account("#{Faker::Lorem.word}#{rand(1_000_000)}", Faker::Internet.email)
    account_id = @account.id
    Account.stubs(:current).returns(@account.reload)
    args = { account_id: @account.id }
    Sidekiq::Testing.inline! do
      CRMApp::Freshsales::DeletedCustomer.new.perform(args)
    end
  ensure
    WebMock.disable_net_connect!
    Account.unstub(:current)
    ThirdCRM.any_instance.unstub(:associated_accounts)
    Account.any_instance.unstub(:admin_email)
  end

  def test_lead_updated_from_freshmarketer_during_account_deletion_with_associated_accounts
    WebMock.allow_net_connect!
    ThirdCRM.any_instance.expects(:update_lead).once
    AdminEmail::AssociatedAccounts.stubs(:find).returns([Account.first, Account.last])
    Account.any_instance.stubs(:admin_email).returns(Faker::Internet.email)
    create_sample_account("#{Faker::Lorem.word}#{rand(1_000_000)}", Faker::Internet.email)
    Account.stubs(:current).returns(@account.reload)
    args = { account_id: @account.id }
    Sidekiq::Testing.inline! do
      CRMApp::Freshsales::DeletedCustomer.new.perform(args)
    end
  ensure
    WebMock.disable_net_connect!
    Account.unstub(:current)
    AdminEmail::AssociatedAccounts.unstub(:find)
    Account.any_instance.unstub(:admin_email)
  end

  def test_new_signup_without_email
    stub_signup_calls
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    Account.stubs(:current).returns(Account.first)
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    parsed_response = parse_response(response.body)
    refute parsed_response['success']
    assert_equal parsed_response['errors'].first, 'Email is invalid'
    assert_response 422
  ensure
    unstub_signup_calls
    Account.unstub(:current)
  end

  def test_new_signup_erroring_on_signup_email_validation
    stub_signup_calls
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = Faker::Internet.email
    Account.stubs(:current).returns(Account.first)
    DomainGenerator.any_instance.stubs(:valid?).raises(StandardError)
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_helpdesk_agent: true, new_plan_test: true }, format: 'json'
    parsed_response = parse_response(response.body)
    refute parsed_response['success']
    assert_equal parsed_response['errors'].first, 'Email is invalid'
    assert_response 422
  ensure
    unstub_signup_calls
    DomainGenerator.any_instance.unstub(:valid?)
    Account.unstub(:current)
  end

  def test_set_onboarding_version_first_50_percent
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.stubs(:get_onboarding_version).returns('personalised_onboarding')
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://freshdesk.com/lp/free-helpdesk-india?u&device=c'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/signup'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert account.account_additional_settings.additional_settings[:onboarding_ab_testing]
    assert_equal account.account_additional_settings.additional_settings[:onboarding_version], 'personalised_onboarding'
  ensure
    unstub_signup_calls
    AccountAdditionalSettings.any_instance.unstub(:get_onboarding_version)
  end

  def test_set_onboarding_version_second_50_percent
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.stubs(:get_onboarding_version).returns('default_onboarding')
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://freshdesk.com/lp/free-helpdesk-india?u&device=c'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/signup'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert account.account_additional_settings.additional_settings[:onboarding_ab_testing]
    assert_equal account.account_additional_settings.additional_settings[:onboarding_version], 'default_onboarding'
  ensure
    unstub_signup_calls
    AccountAdditionalSettings.any_instance.unstub(:get_onboarding_version)
  end

  def test_set_onboarding_version_when_referer_url_is_not_signup
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.stubs(:get_onboarding_version).returns('default_onboarding')
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://google.com'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/lp/free-helpdesk-india?u&device=c'
    session = { current_session: { referrer: landing_url, url: url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } },
                device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' },
                locale: { lang: 'en' }, browser: {}, time: {}, mSegment: 'good' }.to_json
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: session, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    assert account.account_additional_settings.additional_settings[:onboarding_ab_testing]
    assert_equal account.account_additional_settings.additional_settings[:onboarding_version], 'default_onboarding'
  ensure
    unstub_signup_calls
    AccountAdditionalSettings.any_instance.unstub(:get_onboarding_version)
  end

  def test_set_onboarding_version_when_no_session_json_is_present
    stub_signup_calls
    Signup.any_instance.unstub(:save)
    AccountAdditionalSettings.any_instance.stubs(:get_onboarding_version).returns('default_onboarding')
    account_name = Faker::Lorem.word
    domain_name = Faker::Lorem.word
    user_email = 'nofsmonsignup@gleason.name'
    landing_url = 'https://google.com'
    user_name = Faker::Name.name
    url = 'https://freshdesk.com/lp/free-helpdesk-india?u&device=c'
    account_info = { account_name: account_name, account_domain: domain_name, locale: I18n.default_locale, time_zone: 'Chennai',
                     user_name: user_name, user_password: 'test1234', user_password_confirmation: 'test1234',
                     user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }
    user_info = { name: user_name, email: user_email, time_zone: 'Chennai', language: 'en' }
    get :new_signup_free, callback: '', user: user_info, account: account_info, session_json: nil, format: 'json'
    resp = JSON.parse(response.body)
    assert_response 200, resp
    account = Account.find(resp['account_id'])
    refute account.account_additional_settings.additional_settings[:onboarding_ab_testing]
    assert_equal account.account_additional_settings.additional_settings[:onboarding_version], 'default_onboarding'
  ensure
    unstub_signup_calls
    AccountAdditionalSettings.any_instance.unstub(:get_onboarding_version)
  end

  def test_new_signup_should_set_perishable_token_expiry_redis
    stub_signup_calls
    Signup.any_instance.stubs(:account).returns(Account.new)
    Account.stubs(:current).returns(current_account)
    Account.any_instance.stubs(:id).returns(1)
    User.any_instance.stubs(:id).returns(1)
    user_email = Faker::Internet.email
    account_name = Faker::Lorem.word
    get :new_signup_free, callback: '', user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, account: { account_name: account_name, locale: I18n.default_locale, time_zone: 'Chennai', user_name: 'Support', user_password: 'test1234', user_password_confirmation: 'test1234', user_email: user_email, user_helpdesk_agent: true, new_plan_test: true }, session_json: { current_session: { referrer: Faker::Lorem.word, url: Faker::Internet.url, search: { engine: Faker::Lorem.word, query: Faker::Lorem.word } }, device: {}, location: { countryName: 'India', countryCode: 'IND', cityName: 'Chennai', ipAddress: '127.0.0.1' }, locale: 'en', browser: {}, time: {} }.to_json, creditcard: { first_name: Faker::Name.first_name, last_name: Faker::Name.last_name }, address: { address1: Faker::Lorem.word, address2: Faker::Lorem.word, city: Faker::Lorem.word, state: Faker::Lorem.word, zip: Faker::Number.number(6), country: 'India', first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, phone: Faker::Number.number(10) }
    assert_response 200
    perishable_token_key = format(PERISHABLE_TOKEN_EXPIRY, account_id: 1, user_id: 1)
    authroization_token_key = format(AUTHORIZATION_CODE_EXPIRY, account_id: 1)
    assert_equal get_others_redis_key(perishable_token_key), 'true'
    assert_equal get_others_redis_key(authroization_token_key), 'true'
    assert_operator 1800, :<=, get_others_redis_expiry(perishable_token_key)
    assert_operator 1800, :<=, get_others_redis_expiry(authroization_token_key)
  ensure
    Signup.any_instance.unstub(:account)
    Account.unstub(:current)
    Account.any_instance.unstub(:id)
    User.any_instance.unstub(:id)
    unstub_signup_calls
  end
end
