require_relative '../../unit_test_helper'
require_relative '../../../api/helpers/email_mailbox_test_helper.rb'
['utils.rb'].each { |file| require Rails.root.join("lib/email/mailbox/#{file}") }

class Mailbox::UtilsTest < ActiveSupport::TestCase
  include EmailMailboxTestHelper
  include Email::Mailbox::Utils

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_error_type_update
    mailbox = create_email_config(
        support_email: 'test@test12.com',
        imap_mailbox_attributes: {
            imap_authentication: 'plain'
        },
        smtp_mailbox_attributes: {
            smtp_authentication: 'plain'
        }
    )
    mailbox.active = true
    mailbox.save!
    Mailbox::UtilsTest.any_instance.stubs(:oauth_delivery_method?).returns(false)
    Mailbox::UtilsTest.any_instance.stubs(:from).returns(['test@test12.com'])
    update_mailbox_error_type
    mailbox.reload

    assert_equal 535, mailbox.smtp_mailbox.error_type
  ensure
    mailbox.destroy
    Mailbox::UtilsTest.unstub(:oauth_delivery_method?)
    Mailbox::UtilsTest.unstub(:from)
  end
end

