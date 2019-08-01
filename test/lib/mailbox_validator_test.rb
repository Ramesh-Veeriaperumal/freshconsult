require_relative '../api/unit_test_helper'
require 'faker'

class MailboxValidatorTest < ActionView::TestCase
  include MailboxValidator

  def construct_args
    @args = {
      'email_config' => {
        'smtp_mailbox_attributes' => {
          '_destroy' => '0',
          'server_name' => 'smtp.gmail.com',
          'port' => '587',
          'use_ssl' => 'true',
          'authentication' => 'plain',
          'user_name' => Faker::Internet.email,
          'password' => Faker::Lorem.word,
          'domain' => Faker::Lorem.word
        },
        'imap_mailbox_attributes' => {
          '_destroy' => '0',
          'server_name' => 'imap.gmail.com',
          'port' => '993',
          'use_ssl' => 'true',
          'delete_from_server' => '0',
          'authentication' => 'plain',
          'user_name' => Faker::Internet.email,
          'password' => Faker::Lorem.word,
          'folder_list' => {
            "standard"=>["inbox"]
           },
          'application_id' => 1
        }
      }
    }
  end

  def render(response)
    @response = JSON.parse(response[:json])
  end

  def params
    @args.deep_symbolize_keys
  end

  def test_mailbox_validation_with_tls_port
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], true
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_with_ssl_port
    construct_args
    @response = nil
    @args['email_config']['smtp_mailbox_attributes']['port'] = 465
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_ssl).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], true
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_ssl)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_with_login_authentication_type
    construct_args
    @response = nil
    @args['email_config']['imap_mailbox_attributes']['authentication'] = 'login'
    Net::IMAP.any_instance.stubs(:authenticate).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_ssl).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], true
  ensure
    Net::IMAP.any_instance.unstub(:authenticate)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_ssl)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_with_imap_destroy_parameter_set
    construct_args
    @response = nil
    @args['email_config']['imap_mailbox_attributes']['_destroy'] = '1'
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], true
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_with_invalid_imap_and_smtp
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:capability).returns([Faker::Lorem.word])
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).raises(Timeout::Error)
    validate_mailbox_details
    assert_equal @response['success'], false
  end

  def test_mailbox_validation_errors_out_on_idle_not_supported_error
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:capability).returns([Faker::Lorem.word])
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Specified IMAP mail server is not supported. Please use a different one'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:capability)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_errors_out_on_imap_socket_error
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).raises(SocketError)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Could not connect to the imap server. Please verify server name, port and credentials'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_errors_out_on_imap_exceptions
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).raises(StandardError)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Error while verifying the mailbox imap details. Please verify server name, port and credentials'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_errors_out_on_smtp_socket_error
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).raises(SocketError)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Could not connect to the smtp server. Please verify server name, port and credentials'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_errors_out_on_smtp_authentication_error
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).raises(Net::SMTPAuthenticationError)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Error while authenticating the smtp server. Please make sure your user name and password are correct'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_validation_errors_out_on_smtp_exception
    construct_args
    @response = nil
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::SMTP.any_instance.stubs(:enable_starttls).returns(true)
    Net::SMTP.any_instance.stubs(:start).raises(StandardError)
    validate_mailbox_details
    assert_equal @response['success'], false
    assert_equal @response['msg'], 'Error while verifying the mailbox smtp details - Exception'
  ensure
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::SMTP.any_instance.unstub(:enable_starttls)
    Net::SMTP.any_instance.unstub(:start)
  end

  def test_mailbox_configuration_sqs_push
    construct_args
    AwsWrapper::SqsV2.stubs(:send_message).returns(message_id: '1')
  ensure
    AwsWrapper::SqsV2.unstub(:send_message)
  end
end
