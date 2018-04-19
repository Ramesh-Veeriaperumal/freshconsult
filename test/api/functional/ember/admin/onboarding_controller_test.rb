require_relative '../../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'email_helper.rb')

class Ember::Admin::OnboardingControllerTest < ActionController::TestCase
  include AccountTestHelper
  include UsersTestHelper
  include OnboardingTestHelper
  include TicketHelper
  include EmailHelper

  def setup
    super
    before_all
  end

  def before_all
    @user = create_test_account
  end

  def channels_params
    @channels ||= %w[phone forums social]
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
end
