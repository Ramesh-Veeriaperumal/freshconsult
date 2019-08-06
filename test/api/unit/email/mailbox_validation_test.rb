require_relative '../../unit_test_helper'

class Email::MailboxValidationTest < ActionView::TestCase
  def controller_params
    {
      name: Faker::Lorem.characters(30),
      support_email: Faker::Internet.email,
      mailbox_type: 'freshdesk_mailbox'
    }
  end

  def setup
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:has_features?).returns(true)
    Account.any_instance.stubs(:multi_product_enabled?).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:has_features?)
    Account.any_instance.unstub(:multi_product_enabled?)
    Account.unstub(:current)
  end

  def test_success
    mailbox = Email::MailboxValidation.new(controller_params, nil)
    assert mailbox.valid?(:create)
  end

  def test_missing_support_email
    params = controller_params.except(:support_email)
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages

    assert errors.include?('Support email missing_field')
  end

  def test_invalid_mailbox_type
    params = controller_params.merge(mailbox_type: 'something')
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages

    assert errors.include?('Mailbox type not_included')
  end

  def test_custom_mailbox
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: 993,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: 587,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    assert mailbox.valid?(:create)
  end

  def test_invalid_freshdesk_mailbox
    params = controller_params.merge(
      mailbox_type: 'freshdesk_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: 993,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: 587,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages

    assert errors.include?('Custom mailbox invalid_field')
  end

  def test_invalid_authentication
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: 993,
          use_ssl: true,
          authentication: 'some_method',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: 587,
          use_ssl: true,
          authentication: 'some_method',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages
    assert errors.include?('Incoming not_included')
    assert errors.include?('Outgoing not_included')
  end

  def test_invalid_mail_server
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 324_325,
          port: 993,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 32_143,
          port: 587,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages

    assert errors.include?('Incoming datatype_mismatch')
    assert errors.include?('Outgoing datatype_mismatch')
  end

  def test_invalid_port
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: '993',
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: '587',
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages
    assert errors.include?('Incoming datatype_mismatch')
    assert errors.include?('Outgoing datatype_mismatch')
  end

  def test_invalid_ssl
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'both',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: 993,
          use_ssl: 5432,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: 587,
          use_ssl: 345_345,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages
    assert errors.include?('Incoming datatype_mismatch')
    assert errors.include?('Outgoing datatype_mismatch')
  end

  def test_invalid_access_type
    params = controller_params.merge(
      mailbox_type: 'custom_mailbox',
      custom_mailbox: {
        access_type: 'something',
        incoming: {
          mail_server: 'imap.gmail.com',
          port: 993,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: 'password'
        },
        outgoing: {
          mail_server: 'smtp.gmail.com',
          port: 587,
          use_ssl: true,
          authentication: 'plain',
          user_name: Faker::Internet.email,
          password: '[FILTERED]'
        }
      }
    )
    mailbox = Email::MailboxValidation.new(params, nil)
    refute mailbox.valid?(:create)
    errors = mailbox.errors.full_messages
    assert errors.include?('Custom mailbox not_included')
  end
end
