# frozen_string_literal: true

require_relative '../unit_test_helper'
require_relative '../test_helper'
require_relative '../../api/helpers/email_mailbox_test_helper.rb'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require Rails.root.join('lib', 'email_helper.rb')

class ImapMailboxTest < ActionView::TestCase
  include AccountHelper
  include EmailMailboxTestHelper
  include EmailHelper

  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def test_imap_params_for_oauth2_office365_mailbox
    email_config = create_email_config(
      support_email: 'test@test3.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        imap_server_name: 'outlook.office365.com',
        with_refresh_token: true,
        with_access_token: true
      }
    )

    expected = imap_params(email_config.imap_mailbox, to_email: email_config.to_email, provider: 'O365', algo: 'PLAIN')
    actual = JSON.parse(email_config.imap_mailbox.imap_params('create'))
    expected[:mailbox_attributes][:pod_info] = actual['mailbox_attributes']['pod_info']
    match_custom_json actual, expected
  ensure
    email_config.destroy
  end

  def test_imap_params_for_oauth2_gmail_mailbox
    email_config = create_email_config(
      support_email: 'test@test3.com',
      imap_mailbox_attributes: {
        imap_authentication: 'xoauth2',
        with_refresh_token: true,
        with_access_token: true
      }
    )

    expected = imap_params(email_config.imap_mailbox, to_email: email_config.to_email, provider: 'GMAIL', algo: 'PLAIN')
    actual = JSON.parse(email_config.imap_mailbox.imap_params('create'))
    expected[:mailbox_attributes][:pod_info] = actual['mailbox_attributes']['pod_info']
    match_custom_json actual, expected
  ensure
    email_config.destroy
  end

  def test_imap_params_for_plain_office365_mailbox
    email_config = create_email_config(
      imap_mailbox_attributes: { imap_server_name: 'outlook.office365.com' }
    )

    expected = imap_params(email_config.imap_mailbox, to_email: email_config.to_email, provider: 'O365', algo: 'RSA')
    actual = JSON.parse(email_config.imap_mailbox.imap_params('create'))
    expected[:mailbox_attributes][:pod_info] = actual['mailbox_attributes']['pod_info']
    match_custom_json actual, expected
  ensure
    email_config.destroy
  end

  def test_imap_params_for_plain_gmail_mailbox
    email_config = create_email_config(
      imap_mailbox_attributes: { imap_server_name: 'imap.gmail.com' }
    )

    expected = imap_params(email_config.imap_mailbox, to_email: email_config.to_email, provider: 'GMAIL', algo: 'RSA')
    actual = JSON.parse(email_config.imap_mailbox.imap_params('create'))
    expected[:mailbox_attributes][:pod_info] = actual['mailbox_attributes']['pod_info']
    match_custom_json actual, expected
  ensure
    email_config.destroy
  end
end
