require_relative '../../../test_helper'
require_relative '../../../../api/helpers/email_mailbox_test_helper.rb'
require Rails.root.join('spec', 'support', 'email_helper.rb')

module Ember
  class Email::MailboxesControllerTest < ActionController::TestCase
    include Mailbox::HelperMethods
    include EmailMailboxTestHelper
    include EmailHelper

    def setup
      super
      before_all
    end

    def teardown
      Account.any_instance.unstub(:multiple_emails_enabled?)
      User.any_instance.unstub(:has_privilege?)
      super
    end

    def before_all
      Account.any_instance.stubs(:multiple_emails_enabled?).returns(true)
      User.any_instance.stubs(:has_privilege?).returns(true)
    end

    def create_forwarding_test_ticket(email_config)
      email = new_email(
        email_config: email_config.to_email,
        reply: Helpdesk::EMAIL[:default_requester_email],
        from: Helpdesk::EMAIL[:default_requester_email],
        include_to: email_config.to_email
      )
      Account.stubs(:current).returns(@account)
      ticket = Helpdesk::ProcessEmail.new(email).perform
      requester_id = @account.tickets.find(ticket['ticket_id']).requester.id
      user = User.find(requester_id)
      user.email = Helpdesk::EMAIL[:default_requester_email]
      user.save!
    ensure
      Account.unstub(:current)
    end

    def test_send_test_email_for_inactive_mailbox
      mailbox = create_email_config(
        support_email: 'support5@localhost.freshpo.com',
        forward_email: 'localhostfreshpocom5@localhost.freshpo.com',
        name: 'testname'
      )
      mailbox.active = false
      mailbox.save!
      id = mailbox.id
      params = { version: 'private', id: id }
      post :send_test_email, construct_params(params)
      assert_response 204
    end

    def test_send_test_email_for_active_mailbox
      mailbox = create_email_config(
        support_email: 'support2@localhost.freshpo.com',
        name: 'testname'
      )
      mailbox.active = true
      mailbox.save!
      id = mailbox.id
      params = { version: 'private', id: id }
      post :send_test_email, construct_params(params)
      assert_response 412
      match_json(request_error_pattern(:active_mailbox_verification))
    end

    def test_send_test_email_for_custom_mailbox
      mailbox = create_email_config(
        support_email: 'support3@localhost.freshpo.com',
        name: 'testname',
        imap_mailbox_attributes: {
          imap_authentication: 'plain'
        },
        smtp_mailbox_attributes: {
          smtp_authentication: 'plain'
        }
      )
      id = mailbox.id
      params = { version: 'private', id: id }
      post :send_test_email, construct_params(params)
      assert_response 412
      match_json(request_error_pattern(:invalid_custom_mailbox_verification))
    end

    def test_verify_forward_email_failure
      mailbox = create_email_config(
        support_email: 'test@localhost.freshpo.com',
        forward_email: 'localhostfreshpocom@localhost.freshpo.com',
        name: 'testname'
      )
      mailbox.active = false
      mailbox.save!
      id = mailbox.id
      params = { version: 'private', id: id }
      get :verify_forward_email, construct_params(params)
      assert_response 404
      match_json(request_error_pattern(:forwarding_ticket_not_found))
    end

    def test_verify_forward_email_success
      domain = @account.primary_email_config.to_email.split('@')[1]
      mailbox = create_email_config(
        support_email: "test1@#{domain}",
        forward_email: "test1@#{domain}",
        name: 'testname'
      )
      mailbox.active = false
      mailbox.save!
      create_forwarding_test_ticket(mailbox)
      id = mailbox.id
      params = { version: 'private', id: id }
      get :verify_forward_email, construct_params(params)
      assert_response 200
    end
  end
end
