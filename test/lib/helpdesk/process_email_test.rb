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
    @custom_config = @account.email_configs.create!(reply_email: 'test@custom.com', to_email: "customcomtest@#{Account.current.full_domain}")
    @from_email = Faker::Internet.email
    @to_email = Faker::Internet.email
    raise "Account is nil" if @account.blank?
  end

  def teardown
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

  def test_failure_email_with_wildcards_no_config
    Account.current.launch(:prevent_wc_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    failed_response = incoming_email_handler.perform(parsed_to_email)
    assert_equal 'Wildcard Email ', failed_response[:processed_status]
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Account.current.rollback(:prevent_wc_ticket_create)
  end

  def test_success_email_to_the_wild_cards
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
  end

  def test_success_email_to_the_wild_cards_using_allow_check
    Account.current.launch(:prevent_wc_ticket_create)
    Account.current.launch(:allow_wildcard_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
    Account.current.rollback(:prevent_wc_ticket_create)
    Account.current.rollback(:allow_wildcard_ticket_create)
  end

  def test_success_email_to_the_default_support_mailbox
    Account.current.launch(:prevent_wc_ticket_create)
    config = Account.current.email_configs.first
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Account.any_instance.stubs(:email_configs).returns(config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(config)
    Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = config.reply_email
    parsed_to_email = { name: 'test', email: config.to_email, domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
    Account.current.rollback(:prevent_wc_ticket_create)
  end
end
