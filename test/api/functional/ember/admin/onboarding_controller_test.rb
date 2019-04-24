require_relative '../../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'email_helper.rb')

class Ember::Admin::OnboardingControllerTest < ActionController::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include OnboardingTestHelper
  include TicketHelper
  include EmailHelper

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
    @channels ||= %w[phone forums social]
  end

  def unset_anonymous_flag
    @account.account_additional_settings.additional_settings.delete(:anonymous_to_trial)
    @account.account_additional_settings.save
  end

  def test_channel_update_with_valid_channels
    @account.set_account_onboarding_pending
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 204
    assert_channel_selection(channels_params)
  end

  def test_channel_update_with_invalid_channels
    channels_params << 'emai'
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 400
  end

  def test_disable_disablable_channels
    @account.set_account_onboarding_pending
    post :update_channel_config, construct_params(version: 'private', channels: %w[phone forums])
    assert_response 204
  end

  def test_channel_update_after_onboarding_complete
    Account.current.complete_account_onboarding
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 404
    Account.current.set_account_onboarding_pending
  end

  def test_update_activation_email_with_valid_email
    new_email = Faker::Internet.email
    put :update_activation_email, construct_params(version: 'private', new_email: new_email)
    assert_response 204
    assert_equal @user.account.admin_email, new_email
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
    get :forward_email_confirmation, construct_params(version: 'private')
    assert_response 204
    contact = add_new_user(@account, email: 'forwarding-noreply@google.com')

    create_ticket({:subject => "(##{verification_code}) Gmail Forwarding Confirmation - Receive Mail from #{email}",
                   :description => "please click the link below to confirm the request:\n\n#{confirmation_url} \n\nIf you click the link and it appears to be broken, please copy and paste it\ninto a new browser window.",
                   :requester_id => contact.id})
    get :forward_email_confirmation, construct_params(version: 'private')
    assert_response 200
    match_json(forward_email_confirmation_pattern(verification_code, email))
  end

  def test_forward_email_confirmation_with_invalid_email_service_provider
    Account.current.account_configuration.company_info[:email_service_provider] = 'yahoo'
    Account.current.account_configuration.save
    get :forward_email_confirmation, construct_params(version: 'private')
    assert_response 400
  end

  def test_test_email_forwarding
    post :test_email_forwarding, construct_params(version: 'private', attempt: 1, send_to: Faker::Internet.email)
    assert_response 204
    create_forwarding_test_ticket
    post :test_email_forwarding, construct_params(version: 'private', attempt: 2, send_to: Faker::Internet.email)
    assert_response 200
    forward_test_ticket_requester = @account.users.find_by_email(Helpdesk::EMAIL[:default_requester_email])
    forward_test_ticket = @account.tickets.requester_latest_tickets(forward_test_ticket_requester, OnboardingConstants::TICKET_CREATE_DURATION.ago).first
    assert_equal forward_test_ticket.subject, "Woohoo.. Your Freshdesk Test Mail"
  end

  def test_test_email_forwarding_with_valid_attempt
    create_forwarding_test_ticket
    post :test_email_forwarding, construct_params(version: 'private', attempt: 3, send_to: Faker::Internet.email)
    assert_response 200
    post :test_email_forwarding, construct_params(version: 'private', attempt: 4, send_to: Faker::Internet.email)
    assert_response 200
  end

  def test_test_email_forwarding_with_invalid_or_no_attempt
    post :test_email_forwarding, construct_params(version: 'private', send_to: Faker::Internet.email)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 0, send_to: Faker::Internet.email)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 10, send_to: Faker::Internet.email)
    assert_response 400
  end

  def test_test_email_forwarding_with_invalid_or_no_sendto_email
    post :test_email_forwarding, construct_params(version: 'private', attempt: 0)
    assert_response 400
    post :test_email_forwarding, construct_params(version: 'private', attempt: 2, send_to: Faker::Name.name())
    assert_response 400
  end

  def test_test_email_forwarding_with_no_success_email
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
    email[:subject] = "Woohoo.. Your Freshdesk Test Mail"
    email[:text] = "Woohoo.. Your Freshdesk Test Mail"
    email[:html] = "Woohoo.. Your Freshdesk Test Mail"
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

  def test_customize_domain_success
    @account.make_current
    new_domain = Faker::Lorem.word
    put :customize_domain, construct_params(version: 'private', subdomain: new_domain)
    assert_response 200
    assert_equal @account.domain, new_domain
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
    Account.any_instance.stubs(:sandbox?).returns(false)
    Account.any_instance.expects(:enable_fresh_connect).once
    Account.any_instance.expects(:add_to_billing).once
    @controller.expects(:add_to_crm).once
    @controller.expects(:add_account_info_to_dynamo).once
    @controller.expects(:enqueue_for_enrichment).once
    @account.account_additional_settings.mark_account_as_anonymous
    new_admin_email = Faker::Internet.email
    post :anonymous_to_trial, construct_params(version: 'private', admin_email: new_admin_email)
  ensure
    unset_anonymous_flag
    Account.any_instance.unstub(:sandbox?)
  end
end
