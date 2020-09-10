require_relative '../../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'email_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'freshcaller_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')

class Ember::Admin::OnboardingControllerTest < ActionController::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include OnboardingTestHelper
  include TicketHelper
  include EmailHelper
  include Freshcaller::TestHelper
  include FreshchatAccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    super
    before_all
  end

  def teardown
    AdminEmail::AssociatedAccounts.unstub(:find)
  end

  def before_all
    @user = create_test_account
    AdminEmail::AssociatedAccounts.stubs(:find).returns(Array.new(2))
  end

  def channels_params
    @channels_params ||= %w[forums social]
  end

  def unset_anonymous_flag
    @account.account_additional_settings.additional_settings.delete(:anonymous_to_trial)
    @account.account_additional_settings.save
  end

  def test_channel_update_with_valid_channel
    @account.set_account_onboarding_pending
    post :update_channel_config, construct_params(version: 'private', channel: 'forums')
    assert_response 204
    assert_channel_selection(channels_params)
  end

  def test_channel_update_with_invalid_channel
    post :update_channel_config, construct_params(version: 'private', channel: 'em')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :not_included, list: 'phone,freshchat,social,forums')])
  end

  def test_channel_update_with_invalid_type_channel
    post :update_channel_config, construct_params(version: 'private', channel: ['email'])
    assert_response 400
    match_json([bad_request_error_pattern('channel', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_channel_update_with_invalid_field_in_request
    post :update_channel_config, construct_params(version: 'private', test: 'forums')
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_channel_update_without_mandatory_params
    post :update_channel_config, construct_params(version: 'private')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :missing_field)])
  end

  def test_phone_channel_update_when_freshcaller_already_linked
    create_freshcaller_account
    post :update_channel_config, construct_params(version: 'private', channel: 'phone')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :channel_already_present, channel_name: 'Freshcaller', code: :invalid_value)])
  ensure
    @account.freshcaller_account.destroy
    @account.reload
  end

  def test_chat_channel_update_when_freshchat_already_linked
    create_freshchat_account @account
    post :update_channel_config, construct_params(version: 'private', channel: 'freshchat')
    assert_response 400
    match_json([bad_request_error_pattern('channel', :channel_already_present, channel_name: 'Freshchat', code: :invalid_value)])
  ensure
    @account.freshchat_account.destroy
    @account.reload
  end

  def test_phone_channel_update_errors_when_domain_taken
    response_stub = { 'errors' => { 'domain_taken' => true } }
    response_stub.stubs(:body).returns(Faker::Lorem.word)
    response_stub.stubs(:code).returns(200)
    response_stub.stubs(:message).returns(Faker::Lorem.word)
    response_stub.stubs(:headers).returns(word: Faker::Lorem.word)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'phone')
    assert_response 409
    match_json(request_error_pattern(code: 'fcaller_domain_taken', message: 'A freshcaller account is already availabe for your domain. Please link it from admin tab.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_phone_channel_update_errors_when_spam_email
    response_stub = { 'errors' => { 'spam_email' => true } }
    response_stub.stubs(:body).returns(Faker::Lorem.word)
    response_stub.stubs(:code).returns(200)
    response_stub.stubs(:message).returns(Faker::Lorem.word)
    response_stub.stubs(:headers).returns(word: Faker::Lorem.word)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'phone')
    assert_response 409
    match_json(request_error_pattern(code: 'fcaller_spam_email', message: 'The email is considered as spam. Please check it.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_phone_channel_update_errors
    response_stub = { 'errors' => { 'email_taken' => true } }
    response_stub.stubs(:body).returns(Faker::Lorem.word)
    response_stub.stubs(:code).returns(200)
    response_stub.stubs(:message).returns(Faker::Lorem.word)
    response_stub.stubs(:headers).returns(word: Faker::Lorem.word)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'phone')
    assert_response 409
    match_json(request_error_pattern(code: 'fcaller_link_error', message: 'There was an issue in creating your freshcaller account. Please contact support.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_phone_channel_update_succeeds
    response_stub = { 'freshcaller_account_id' => Faker::Number.number(5), 'freshcaller_account_domain' => Faker::Lorem.words(5), 'user' => { 'id' => Faker::Number.number(5) } }
    response_stub.stubs(:body).returns(Faker::Lorem.word)
    response_stub.stubs(:code).returns(200)
    response_stub.stubs(:message).returns(Faker::Lorem.word)
    response_stub.stubs(:headers).returns(word: Faker::Lorem.word)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'phone')
    assert_response 204
  ensure
    HTTParty::Request.any_instance.unstub(:post)
  end

  def test_freshchat_channel_update_errors_when_email_already_present
    response_stub = { 'errorCode' => 'ERR_LOGIN_TO_SIGNUP' }
    response_stub.stubs(:code).returns(200)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'freshchat')
    assert_response 409
    match_json(request_error_pattern(code: 'fchat_account_already_presennt', message: 'A freshchat account is already registered with your email. Please link it from admin tab.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_freshchat_channel_update_errors_when_user_already_logged
    response_stub = { 'errorCode' => 'ERR_ALREADY_LOGGED_IN' }
    response_stub.stubs(:code).returns(200)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'freshchat')
    assert_response 409
    match_json(request_error_pattern(code: 'fchat_account_logged_in', message: 'You are already logged in to freshchat. Please logout and try again.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_freshchat_channel_update_errors
    response_stub = { 'errorCode' => 'SOMETHING_WENT_WRONG' }
    response_stub.stubs(:code).returns(200)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'freshchat')
    assert_response 409
    match_json(request_error_pattern(code: 'fchat_link_error', message: 'There was an issue in creating your freshchat account. Please contact support.'))
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_freshchat_channel_update_succeeds
    response_stub = { 'userInfoList' => [{ 'appId' => Faker::Lorem.word, 'appKey' => Faker::Lorem.word }] }
    response_stub.stubs(:code).returns(200)
    HTTParty::Request.any_instance.stubs(:perform).returns(response_stub)
    post :update_channel_config, construct_params(version: 'private', channel: 'freshchat')
    assert_response 204
  ensure
    HTTParty::Request.any_instance.unstub(:perform)
  end

  def test_update_activation_email_with_valid_email
    new_email = Faker::Internet.email
    put :update_activation_email, construct_params(version: 'private', new_email: new_email)
    assert_response 204
    assert_equal @user.account.admin_email, new_email
  end

  def test_update_activation_email_with_active_freshid_agent_email
    new_email = Faker::Internet.email
    User.any_instance.stubs(:active_freshid_agent?).returns(true)
    put :update_activation_email, construct_params(version: 'private', new_email: new_email)
    assert_response 204
    assert_equal @user.account.admin_email, new_email
  ensure
    User.any_instance.unstub(:active_freshid_agent?)
  end

  def test_update_activation_email_with_invalid_email
    put :update_activation_email, construct_params(version: 'private', new_email: Faker::Lorem.word)
    assert_response 400
  end

  def test_update_activation_email_with_empty_email
    put :update_activation_email, construct_params(version: 'private', new_email: '')
    assert_response 400
  end

  def test_update_activation_email_with_no_email_field
    put :update_activation_email, construct_params(version: 'private')
    assert_response 400
  end

  def test_resend_activation_email
    get :resend_activation_email, construct_params(version: 'private')
    assert_response 204
  end

  def test_update_activation_email_save_failure
    user = add_new_user(@account)
    put :update_activation_email, construct_params(version: 'private', new_email: user.email)
    errors = JSON.parse(@response.body)['errors']
    assert_response 409
    assert_equal errors[0]['message'], 'It should be a unique value'
    user.destroy
  ensure
    User.any_instance.unstub(:save)
  end

  def test_forward_email_confirmation
    confirmation_url = "https://mail.google.com/mail/vf-%5BANGjdJ8Q_KQ1iwRAtX8n7Hjw_fcn5uDnDGHEv243ErEm2hz66A%5D-iSlLnHB9XCIBvkSa-7-JUNlapWo"
    verification_code = Faker::Number.number(10).to_s
    email = Faker::Internet.email
    Account.current.account_configuration.company_info[:email_service_provider] = 'google'
    Account.current.account_configuration.save
    get :forward_email_confirmation, controller_params(version: 'private', requested_time: Time.zone.now.iso8601)
    assert_response 204
    contact = add_new_user(@account, email: 'forwarding-noreply@google.com')
    ticket = create_ticket(subject: "(##{verification_code}) Gmail Forwarding Confirmation - Receive Mail from #{email}",
                            description: "please click the link below to confirm the request:\n\n#{confirmation_url} \n\nIf you click the link and it appears to be broken, please copy and paste it\ninto a new browser window.",
                            requester_id: contact.id, created_at: Time.zone.now + 5.minutes)
    get :forward_email_confirmation, controller_params(version: 'private', requested_time: (ticket.created_at - 5.minutes).iso8601)
    assert_response 200
    match_json(forward_email_confirmation_pattern(verification_code, email))
  end

  def test_forward_email_confirmation_with_invalid_email_service_provider
    Account.current.account_configuration.company_info[:email_service_provider] = 'yahoo'
    Account.current.account_configuration.save
    get :forward_email_confirmation, controller_params(version: 'private', requested_time: Time.zone.now.iso8601)
    assert_response 400
  end

  def test_forward_email_confirmation_without_required_params
    get :forward_email_confirmation, controller_params(version: 'private')
    assert_response 400
    match_json([bad_request_error_pattern(:requested_time, :missing_field)])
  end

  def test_forward_email_confirmation_without_invalid_params
    get :forward_email_confirmation, controller_params(version: 'private', attempt: 4)
    assert_response 400
    match_json([bad_request_error_pattern(:attempt, :invalid_field)])
  end

  def test_forward_email_confirmation_with_invalid_date_format
    get :forward_email_confirmation, controller_params(version: 'private', requested_time: Faker::Lorem.word)
    assert_response 400
    match_json([bad_request_error_pattern(:requested_time, :invalid_date, code: :invalid_value, accepted: 'combined date and time ISO8601')])
  end

  def test_email_forwarding
    post :test_email_forwarding, construct_params(version: 'private', attempt: 1, send_to: Faker::Internet.email)
    assert_response 204
    create_forwarding_test_ticket
    post :test_email_forwarding, construct_params(version: 'private', attempt: 2, send_to: Faker::Internet.email)
    assert_response 200
    forward_test_ticket_requester = @account.users.find_by_email(Helpdesk::EMAIL[:default_requester_email])
    forward_test_ticket = @account.tickets.requester_latest_tickets(forward_test_ticket_requester, OnboardingConstants::TICKET_CREATE_DURATION.ago).first
    assert_equal forward_test_ticket.subject, OnboardingConstants::TEST_FORWARDING_SUBJECT
  end

  def test_email_forwarding_with_valid_attempt
    create_forwarding_test_ticket
    post :test_email_forwarding, construct_params(version: 'private', attempt: 3, send_to: Faker::Internet.email)
    assert_response 200
    post :test_email_forwarding, construct_params(version: 'private', attempt: 4, send_to: Faker::Internet.email)
    assert_response 200
  end

  def test_email_forwarding_with_invalid_or_no_attempt
    post :test_email_forwarding, construct_params(version: 'private', send_to: Faker::Internet.email)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 0, send_to: Faker::Internet.email)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 10, send_to: Faker::Internet.email)
    assert_response 400
  end

  def test_email_forwarding_with_invalid_or_no_sendto_email
    post :test_email_forwarding, construct_params(version: 'private', attempt: 0)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 2, send_to: Faker::Name.name())
    assert_response 400
  end

  def test_email_forwarding_with_no_success_email
    delete_forwarding_test_ticket
    post :test_email_forwarding, construct_params(version: 'private', attempt: 2, send_to: Faker::Internet.email)
    assert_response 204
    post :test_email_forwarding, construct_params(version: 'private', attempt: 3, send_to: Faker::Internet.email)
    assert_response 204
    post :test_email_forwarding, construct_params(version: 'private', attempt: 4, send_to: Faker::Internet.email)
    assert_response 204
  end

  def create_forwarding_test_ticket
    email = new_email({:email_config => @account.primary_email_config.to_email,
      :reply => Helpdesk::EMAIL[:default_requester_email]})
    email[:subject] = OnboardingConstants::TEST_FORWARDING_SUBJECT
    email[:text] = OnboardingConstants::TEST_FORWARDING_SUBJECT
    email[:html] = OnboardingConstants::TEST_FORWARDING_SUBJECT
    Helpdesk::ProcessEmail.new(email).perform
  end

  def delete_forwarding_test_ticket
    forward_test_ticket_requester = @account.users.find_by_email(Helpdesk::EMAIL[:default_requester_email])
    forward_test_tickets = @account.tickets.requester_latest_tickets(forward_test_ticket_requester, OnboardingConstants::TICKET_CREATE_DURATION.ago)
    forward_test_tickets.each(&:destroy)
  end

  def test_validate_domain_failure
    existing_domain = @account.domain
    post :validate_domain_name, construct_params(version: 'private', subdomain: existing_domain)
    assert_response 400
  end

  def test_validate_domain_success
    random_digits = SecureRandom.random_number.to_s[2..4]
    new_domain = @account.domain + random_digits
    post :validate_domain_name, construct_params(version: 'private', subdomain: new_domain)
    assert_response 204
  end

  def test_suggest_domains
    @account.make_current
    expected_subdomains = DomainGenerator.sample(@account.admin_email, 3)
    get :suggest_domains, construct_params(version: 'private')
    assert_response 200
    suggested_subdomains = JSON.parse(response.body)["subdomains"]
    assert_equal expected_subdomains, suggested_subdomains
  end

  def test_customize_domain_failure
    @account.make_current
    existing_domain = @account.domain
    put :customize_domain, construct_params(version: 'private', subdomain: existing_domain)
    assert_response 400
  end

  def test_customize_domain_with_mars_domains
    assert_raises(ActiveRecord::RecordInvalid) do
      put :customize_domain, construct_params(version: 'private', subdomain: 'mars-us')
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      put :customize_domain, construct_params(version: 'private', subdomain: 'mars-euc')
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      put :customize_domain, construct_params(version: 'private', subdomain: 'mars-ind')
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      put :customize_domain, construct_params(version: 'private', subdomain: 'mars-au')
    end
  end

  def test_customize_domain_success
    @account.make_current
    new_domain = Faker::Internet.domain_word
    put :customize_domain, construct_params(version: 'private', subdomain: new_domain)
    assert_response 200
    assert_equal @account.domain, new_domain
  end

  def test_customize_domain_fluffy
    @account.make_current
    fluffy_email_account = Fluffy::AccountV2.new(account_id: @account.id,
                                                 name: @account.full_domain,
                                                 limit: 100,
                                                 granularity: 'MINUTE')
    fluffy_api_account = Fluffy::Account.new(name: @account.full_domain,
                                             limit: 100,
                                             granularity: 'MINUTE')
    @account.stubs(:fluffy_integration_enabled?).returns(true)
    @account.stubs(:fluffy_email_enabled?).returns(true)
    @account.stubs(:current_fluffy_limit).returns(fluffy_api_account)
    @account.stubs(:current_fluffy_email_limit).returns(fluffy_email_account)
    @account.stubs(:destroy_fluffy_account).returns(true)
    Fluffy::FRESHDESK.stubs(:fluffy_add_account).returns(true)
    Fluffy::FRESHDESK_EMAIL.stubs(:fluffy_add_account).returns(true)
    @account.expects(:destroy_fluffy_account).once
    @account.expects(:destroy_fluffy_email_account).once
    Fluffy::FRESHDESK.expects(:fluffy_add_account).once
    Fluffy::FRESHDESK_EMAIL.expects(:fluffy_add_account).once
    new_domain = Faker::Internet.domain_word
    put :customize_domain, construct_params(version: 'private', subdomain: new_domain)
    assert_response 200
    assert_equal @account.domain, new_domain
  ensure
    @account.unstub(:fluffy_integration_enabled?)
    @account.unstub(:fluffy_email_enabled?)
    @account.unstub(:current_fluffy_limit)
    @account.unstub(:current_fluffy_email_limit)
    @account.unstub(:destroy_fluffy_account)
    Fluffy::FRESHDESK_EMAIL.unstub(:fluffy_add_account)
    Fluffy::FRESHDESK.unstub(:fluffy_add_account)
  end

  def test_customize_domain_fluffy_without_fluffy_account
    @account.make_current
    @account.stubs(:fluffy_integration_enabled?).returns(true)
    @account.stubs(:fluffy_email_enabled?).returns(true)
    @account.stubs(:current_fluffy_email_limit).returns(nil)
    @account.stubs(:current_fluffy_limit).returns(nil)
    @account.stubs(:create_fluffy_email_account).returns(true)
    @account.stubs(:create_fluffy_account).returns(true)
    @account.expects(:create_fluffy_email_account).once
    @account.expects(:create_fluffy_account).once
    new_domain = Faker::Internet.domain_word
    put :customize_domain, construct_params(version: 'private', subdomain: new_domain)
    assert_response 200
    assert_equal @account.domain, new_domain
  ensure
    @account.unstub(:fluffy_integration_enabled?)
    @account.unstub(:fluffy_email_enabled?)
    @account.unstub(:current_fluffy_email_limit)
    @account.unstub(:current_fluffy_limit)
    @account.unstub(:create_fluffy_email_account)
    @account.unstub(:create_fluffy_account)

    Fluffy::FRESHDESK_EMAIL.unstub(:fluffy_add_account)
  end

  def test_anonymous_to_trial_already_trial
    admin_email = Faker::Internet.email
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: admin_email)
    assert_response 400
    pattern = validation_error_pattern(bad_request_error_pattern(:anonymous_to_trial,
                                                                 :account_in_trial, code: 'invalid_value'))
    match_json(pattern)
  end

  def test_anonymous_to_trial_email_limit_reached
    admin_email = Faker::Internet.email
    @account.account_additional_settings.mark_account_as_anonymous
    AdminEmail::AssociatedAccounts.stubs(:find).returns(Array.new(11))
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: admin_email)
    assert_response 400
    pattern = validation_error_pattern(bad_request_error_pattern(:anonymous_to_trial,
                                                                 :email_limit_reached, code: 'invalid_value', limit: Signup::MAX_ACCOUNTS_COUNT))
    match_json(pattern)
  ensure
    AdminEmail::AssociatedAccounts.unstub(:find)
    unset_anonymous_flag
  end

  def test_anonymous_to_trial_email_increase_signup_count
    admin_email = Faker::Internet.email
    @account.account_additional_settings.mark_account_as_anonymous
    add_member_to_redis_set(INCREASE_DOMAIN_FOR_EMAILS, admin_email)
    AdminEmail::AssociatedAccounts.stubs(:find).returns(Array.new(11))
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: admin_email)
    assert_response 200
    ensure
      AdminEmail::AssociatedAccounts.unstub(:find)
      unset_anonymous_flag
      remove_member_from_redis_set(INCREASE_DOMAIN_FOR_EMAILS, admin_email)
  end  

  def test_anonymous_to_trial_success
    @account.account_additional_settings.mark_account_as_anonymous
    new_admin_email = Faker::Internet.email
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: new_admin_email)
    assert_response 200
    match_json(anonymous_to_trial_success_pattern(new_admin_email))
  end

  def test_anonymous_to_trial_portal_and_email_config_as_default_name
    @account.account_additional_settings.mark_account_as_anonymous
    Portal.any_instance.stubs(:name).returns(AccountConstants::ANONYMOUS_ACCOUNT_NAME)
    EmailConfig.any_instance.stubs(:name).returns(AccountConstants::ANONYMOUS_ACCOUNT_NAME)
    new_admin_email = Faker::Internet.email
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: new_admin_email)
    Portal.any_instance.unstub(:name)
    EmailConfig.any_instance.unstub(:name)
    assert_response 200
    match_json(anonymous_to_trial_success_pattern(new_admin_email))
    assert_equal @account.main_portal.name, company_name_from_email
    assert_equal @account.primary_email_config.name, company_name_from_email
  ensure
    Portal.any_instance.unstub(:name)
    EmailConfig.any_instance.unstub(:name)
  end

  def test_anonymous_to_trial_user_update_failure
    user = add_new_user(@account)
    @account.account_additional_settings.mark_account_as_anonymous
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: user.email)
    errors = JSON.parse(@response.body)['errors']
    assert_response 409
    assert_equal errors[0]['message'], 'It should be a unique value'
  ensure
    user.destroy
    unset_anonymous_flag
  end

  def test_anonymous_to_trial_user_account_update_failure
    admin_email = Faker::Internet.email
    AccountAdditionalSettings.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid)
    @account.account_additional_settings.mark_account_as_anonymous
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: admin_email)
    assert_not_equal admin_email, @account.admin_email
    assert_response 500
  ensure
    AccountAdditionalSettings.any_instance.unstub(:save!)
    unset_anonymous_flag
  end

  def test_name_company_name_from_email_methods
    admin_email = 'Ethan.hunt@freshdesk.com'
    @account.account_additional_settings.mark_account_as_anonymous
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: admin_email)
    parsed_response = JSON.parse(response.body)
    assert_response 200
    assert_equal parsed_response['first_name'], 'Ethan hunt'
    assert_equal parsed_response['last_name'], 'Ethan hunt'
    assert_equal parsed_response['company_name'], 'freshdesk'
  end

  def test_third_party_apps_called_for_anonymous_account
    params = signup_params
    key = format(ACCOUNT_SIGN_UP_PARAMS, account_id: @account.id)
    set_others_redis_key(key, params.to_json)
    Account.any_instance.stubs(:sandbox?).returns(false)
    Account.any_instance.expects(:enable_fresh_connect).once
    Account.any_instance.expects(:add_to_billing).once
    @controller.expects(:add_to_crm).with(@account.id, params.symbolize_keys!).once
    @controller.expects(:add_account_info_to_dynamo).once
    @controller.expects(:enqueue_for_enrichment).once
    @account.account_additional_settings.mark_account_as_anonymous
    new_admin_email = Faker::Internet.email
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: new_admin_email)
  ensure
    remove_others_redis_key(key)
    unset_anonymous_flag
    Account.any_instance.unstub(:sandbox?)
  end
end
