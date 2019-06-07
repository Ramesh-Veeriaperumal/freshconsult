require_relative '../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class AccountsControllerTest < ActionController::TestCase
  include Redis::RedisKeys
  include Redis::OthersRedis
  include UsersHelper
  include AccountTestHelper

  def stub_signup_calls
    Signup.any_instance.stubs(:save).returns(true)
    AccountInfoToDynamo.stubs(:perform_async).returns(true)
    Account.any_instance.stubs(:mark_new_account_setup_and_save).returns(true)
    Account.any_instance.stubs(:launched?).returns(true)
    Account.any_instance.stubs(:anonymous_account?).returns(false)
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
    User.any_instance.unstub(:deliver_admin_activation)
    User.any_instance.unstub(:perishable_token)
    User.any_instance.unstub(:reset_perishable_token!)
  end

  def current_account
    Account.first
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
    user_email = "#{Account::RESERVED_DOMAINS.sample}@freshdesk.com"
    params = account_params_without_domain(user_email)
    get :new_signup_free, params
    subdomain = user_email.split('@')[0]
    full_domain = Regexp.new("#{subdomain}(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')}).freshpo.com")
    response_url = parse_response(@response.body)['url'].split('/')[2]
    assert_match(full_domain, response_url)
    assert_response 200
  ensure
    Freemail.unstub(:free?)
  end

  def test_signup_with_reserved_keyword_in_email_domain
    Freemail.stubs(:free?).returns(false)
    user_email = "#{Faker::Lorem.word}@#{Account::RESERVED_DOMAINS.sample}.com"
    params = account_params_without_domain(user_email)
    get :new_signup_free, params
    subdomain = user_email.split('@')[1].split('.')[0]
    full_domain = Regexp.new("#{subdomain}(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')}).freshpo.com")
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
    get :signup_validate_domain, domain: Faker::Lorem.word, format: 'json'
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
    get :update_domain, company_domain: Faker::Lorem.word
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
    get :update_domain, company_domain: Faker::Lorem.word, format: 'json'
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
    RestrictedHelpdeskFeature.any_instance.stubs(:safe_send).returns(true)
    TwitterSigninFeature.any_instance.stubs(:destroy).returns(true)
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
    RestrictedHelpdeskFeature.any_instance.unstub(:safe_send)
    TwitterSigninFeature.any_instance.unstub(:destroy)
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
    Account.any_instance.stubs(:paid_account?).returns(true)
    Account.any_instance.stubs(:add_churn).returns(true)
    Account.any_instance.stubs(:schedule_cleanup).returns(true)
    Account.any_instance.stubs(:update_crm).returns(true)
    Account.any_instance.stubs(:send_account_deleted_email).returns(true)
    Account.any_instance.stubs(:create_deleted_customers_info).returns(true)
    Account.any_instance.stubs(:clear_account_data).returns(true)
    post :cancel, confirm: true
    assert_response 302

    Account.any_instance.stubs(:paid_account?).returns(false)
    post :cancel, confirm: true
    assert_response 302
  ensure
    Billing::Subscription.any_instance.unstub(:cancel_subscription)
    Account.any_instance.unstub(:paid_account?)
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
    EnableMultilingualFeature.any_instance.stubs(:create).returns(true)
    put :update_languages, id: Account.first.id, account: { account_additional_settings_attributes: { supported_languages: ['ar', 'ca', 'et'] }, main_portal_attributes: {} }
    assert_response 302
    assert_includes response.redirect_url, edit_account_path
  ensure
    Account.any_instance.unstub(:save)
    Account.any_instance.unstub(:features_included?)
    Account.any_instance.unstub(:supported_languages)
    EnableMultilingualFeature.any_instance.unstub(:create)
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
    Account.any_instance.stubs(:onboarding_applicable?).returns(true)
    anonymous_signup_key = ANONYMOUS_ACCOUNT_SIGNUP_ENABLED
    set_others_redis_key(anonymous_signup_key, true)
    onboarding_v2_key = ONBOARDING_V2_ENABLED
    set_others_redis_key(onboarding_v2_key, true)
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
    assert_equal account.launched?(:onboarding_v2), true
    assert_equal account.launched?(:new_onboarding), true
    assert_match(/freshdeskdemo[0-9]{13}@example.com/, account.admin_email)
    assert_match(/demo(#{DomainGenerator::DOMAIN_SUGGESTIONS.join('|')})?[0-9]{13}.freshpo.com/, account.full_domain)
    assert_not_nil account.id
    key = format(ACCOUNT_SIGN_UP_PARAMS, account_id: account.id)
    value = JSON.parse(get_others_redis_key(key)).symbolize_keys!
    assert_equal value[:fs_cookie], params[:fs_cookie]
    assert_equal value[:signup_id], params[:signup_id]
  ensure
    Account.any_instance.unstub(:anonymous_account?)
    Account.any_instance.unstub(:onboarding_applicable?)
    remove_others_redis_key(anonymous_signup_key)
    remove_others_redis_key(onboarding_v2_key)
    account.destroy if account.present?
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
end
