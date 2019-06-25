require_relative '../../test_helper'
require_relative '../../api/unit_test_helper'
require_relative '../../core/helpers/account_test_helper'
require_relative '../../core/helpers/tickets_test_helper'

# Test cases for email process
class ProcessEmailTest < ActiveSupport::TestCase
  include AccountTestHelper
  include CoreTicketsTestHelper

  def setup
    super
    @account = Account.first || create_test_account
    @account = Account.first
    Account.stubs(:current).returns(@account)
    Account.stubs(:find_by_full_domain).returns(@account)
    Account.current.launch(:enable_wildcard_ticket_create)
    Account.current.launch(:check_wc_fwd)
    @custom_config = @account.email_configs.create!(reply_email: 'test@custom.com', to_email: "customcomtest@#{Account.current.full_domain}")
    @from_email = Faker::Internet.email
    @to_email = Faker::Internet.email
    raise "Account is nil" if @account.blank?
  end

  def teardown
    Account.current.rollback(:enable_wildcard_ticket_create)
    Account.current.rollback(:check_wc_fwd)
    Account.unstub(:current)
    Account.unstub(:find_by_full_domain)
    @custom_config.destroy
  end

  def default_params(id, subject = nil)
    if subject.present?
      { from: @from_email, to: @to_email, subject: subject, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
    else
      { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
    end
  end

  def test_collab_email_reply_invited
    req_params = { subject: 'Invited to Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_mentioned
    req_params = { subject: 'Mentioned in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_group_mentioned
    req_params = { subject: 'mentioned in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_reply
    req_params = { subject: 'Reply in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_follower_multi_messages
    req_params = { subject: 'Team Huddle - New Messages in [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_follower_single_message
    req_params = { subject: 'Team Huddle - New Message in [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, true
  end

  def test_collab_email_reply_should_process_1
    req_params = { subject: 'Invited to Team Huddle -y [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_2
    req_params = { subject: 'Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_3
    req_params = { subject: 'Random subject to an email reply' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_4
    req_params = { subject: 'Random subject to an email reply' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_collab_email_reply_should_process_5
    req_params = { subject: 'reply in Team Huddle - [#' }
    process_email = Helpdesk::ProcessEmail.new(req_params)
    is_cer = process_email.send(:collab_email_reply?, req_params[:subject])
    assert_equal is_cer, false
  end

  def test_failure_of_incoming_email_to_the_forward_address
    Account.current.launch(:prevent_fwd_email_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Account.any_instance.stubs(:email_configs).returns(@custom_config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(@custom_config)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "customcomtest@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: @custom_config.to_email, domain: 'custom.com' }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    failed_response = incoming_email_handler.perform(parsed_to_email)
    assert_equal 'Email sent to freshdesk mail box directly ', failed_response[:processed_status]
  ensure
    Account.current.rollback(:prevent_fwd_email_ticket_create)
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
  end

  def test_failure_email_to_the_forward_address_wildcards_not_allowed
    Account.current.launch(:prevent_fwd_email_ticket_create)
    Account.current.rollback(:enable_wildcard_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Account.any_instance.stubs(:email_configs).returns(@custom_config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(@custom_config)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "customcomtest@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: @custom_config.to_email, domain: 'custom.com' }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    failed_response = incoming_email_handler.perform(parsed_to_email)
    assert_equal 'Email sent to freshdesk mail box directly ', failed_response[:processed_status]
  ensure
    Account.current.rollback(:prevent_fwd_email_ticket_create)
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
  end

  def test_failure_email_with_wildcards
    Account.current.rollback(:enable_wildcard_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Account.any_instance.stubs(:email_configs).returns(@custom_config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(@custom_config)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: @custom_config.to_email, domain: 'custom.com' }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    failed_response = incoming_email_handler.perform(parsed_to_email)
    assert_equal 'Email address does not match the configured emails ', failed_response[:processed_status]
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
  end

  def test_success_email_to_the_fd_forward_address
    Account.current.launch(:prevent_fwd_email_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    config = Account.current.email_configs.first
    Account.any_instance.stubs(:email_configs).returns(config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(config)
    Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test <test@gmail.com>, support@#{Account.current.full_domain}"
    parsed_to_email = { name: Account.current.name, email: config.to_email, domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    Account.current.rollback(:prevent_fwd_email_ticket_create)
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
  end

  def test_success_email_cc_to_the_fd_forward_address
    Account.current.launch(:prevent_fwd_email_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    config = Account.current.email_configs.first
    Account.any_instance.stubs(:email_configs).returns(config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(config)
    Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = 'test <test@gmail.com>'
    params[:cc] = "support@#{Account.current.full_domain}"
    parsed_to_email = { name: Account.current.name, email: config.to_email, domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    Account.current.rollback(:prevent_fwd_email_ticket_create)
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
  end
end
