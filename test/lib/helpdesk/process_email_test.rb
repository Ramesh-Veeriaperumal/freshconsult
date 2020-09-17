require_relative '../../test_helper'
require_relative '../../api/unit_test_helper'
require_relative '../../core/helpers/account_test_helper'
require_relative '../../core/helpers/tickets_test_helper'
require_relative '../../../lib/email/perform_util'
# Test cases for email process
class ProcessEmailTest < ActiveSupport::TestCase
  include AccountTestHelper
  include CoreTicketsTestHelper
  include Email::PerformUtil
  def setup
    super
    @account = Account.first || create_test_account
    @account = Account.first
    Account.stubs(:current).returns(@account)
    Account.stubs(:find_by_full_domain).returns(@account)
    @custom_config = @account.email_configs.create!(reply_email: 'test@custom.com', to_email: "customcomtest@#{Account.current.full_domain}")
    @from_email = Faker::Internet.email
    @to_email = Faker::Internet.email
    @in_reply_to = "<#{Faker::Internet.email}>"
    @parse_name = Faker::Name.name
    @parse_email = Faker::Internet.email
    @agent_email = @account.technicians.first.email
    @parsed_to_email = { name: Faker::Name.name, email: @custom_config.to_email, domain: @account.full_domain }
    @account.remove_feature :disable_agent_forward
    Account.any_instance.stubs(:parse_replied_email_enabled?).returns(true)
    raise "Account is nil" if @account.blank?
  end

  def teardown
    Account.unstub(:current)
    Account.unstub(:find_by_full_domain)
    @custom_config.destroy
  end

  def default_params(id, subject = nil)
    if subject.present?
      { from: @from_email, to: @to_email, subject: subject, attachments: 0, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
    else
      { from: @from_email, to: @to_email, attachments: 0, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
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
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::ProcessEmail.new(params)
    failed_response = incoming_email_handler.perform(parsed_to_email)
    assert_equal 'Wildcard Email ', failed_response[:processed_status]
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
  end

  def test_success_email_to_the_wild_cards
    Account.current.launch(:allow_wildcard_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::ProcessEmail.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::ProcessEmail.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::ProcessEmail.any_instance.unstub(:add_to_or_create_ticket)
  end

  def test_success_email_to_the_wild_cards_using_allow_check
    Account.current.launch(:allow_wildcard_ticket_create)
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::ProcessEmail.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = "test+1223@#{Account.current.full_domain}"
    parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::ProcessEmail.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::ProcessEmail.any_instance.unstub(:add_to_or_create_ticket)
    Account.current.rollback(:allow_wildcard_ticket_create)
  end

  def test_success_email_to_the_default_support_mailbox
    config = Account.current.email_configs.first
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Account.any_instance.stubs(:email_configs).returns(config)
    EmailConfig.any_instance.stubs(:find_by_to_email).returns(config)
    Helpdesk::ProcessEmail.any_instance.stubs(:add_to_or_create_ticket).returns(true)
    params = default_params(Faker::Lorem.characters(50), 'Test Subject')
    params[:to] = config.reply_email
    parsed_to_email = { name: 'test', email: config.to_email, domain: Account.current.full_domain }
    incoming_email_handler = Helpdesk::ProcessEmail.new(params)
    assert_equal incoming_email_handler.perform(parsed_to_email), true
  ensure
    ShardMapping.unstub(:fetch_by_domain)
    Account.any_instance.unstub(:email_configs)
    EmailConfig.any_instance.unstub(:find_by_to_email)
    Helpdesk::ProcessEmail.any_instance.unstub(:add_to_or_create_ticket)
  end

  def test_email_perform_save_incoming_time
    id = Faker::Lorem.characters(50)
    subject = 'Test Subject'
    params = default_params(id, subject)
    params[:x_received_at] = Time.now.utc.iso8601
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
    params[:attachments] = 0
    process_email = Helpdesk::ProcessEmail.new(params)
    success_response = process_email.perform(domain: 'localhost.freshpo.com',
                                             email: 'support@localhost.freshpo.com')
    assert_equal success_response[:processed_status], 'success'
  end

  def test_email_perform_save_incoming_time_internal_date
    id = Faker::Lorem.characters(50)
    subject = 'Test Subject'
    params = default_params(id, subject)
    params[:internal_date] = Time.zone.now.to_s
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
    params[:attachments] = 0
    process_email = Helpdesk::ProcessEmail.new(params)
    success_response = process_email.perform(domain: 'localhost.freshpo.com',
                                             email: 'support@localhost.freshpo.com')
    assert_equal success_response[:processed_status], 'success'
  end

  def test_email_perform_add_email_to_ticket_with_time
    id = Faker::Lorem.characters(50)
    subject = 'Test Subject'
    params = default_params(id, subject)
    params[:internal_date] = Time.zone.now.to_s
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
    Helpdesk::ProcessEmail.any_instance.stubs(:large_email).returns(false)
    params[:attachments] = 0
    params[:text] = 'sample text'
    process_email = Helpdesk::ProcessEmail.new(params)
    add_email_response = process_email
                             .safe_send(:add_email_to_ticket, Helpdesk::Ticket.first, { email: 'customfrom@test.com' }, { email: 'customto@test.com' }, User.first)
    assert_equal 'success', add_email_response[:processed_status]
  end

  def test_email_perform_add_email_to_ticket_with_received_at
    id = Faker::Lorem.characters(50)
    subject = 'Test Subject'
    params = default_params(id, subject)
    params[:x_received_at] = Time.zone.now.to_s
    ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
    Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
    Helpdesk::ProcessEmail.any_instance.stubs(:large_email).returns(false)
    params[:attachments] = 0
    params[:text] = 'sample text'
    process_email = Helpdesk::ProcessEmail.new(params)
    add_email_response = process_email
                             .safe_send(:add_email_to_ticket, Helpdesk::Ticket.first, { email: 'customfrom@test.com' }, { email: 'customto@test.com' }, User.first)
    assert_equal 'success', add_email_response[:processed_status]
  end

  def test_prevent_lang_detect_for_spam
    account = Account.current
    user = account.users.first
    user.language = 'ar'
    user.save
    ticket = account.tickets.first
    ticket.spam = true
    assign_language(user, account, ticket)
    user = account.users.find_by_id(user.id)
    assert_equal account.language, user.language
  ensure
    Helpdesk::Ticket.any_instance.unstub(:spam_or_deleted?)
  end

  def test_lang_detect_for_non_spam
    account = Account.current
    user = account.users.first
    user.language = 'ar'
    user.save
    ticket = account.tickets.first
    ticket.spam = false
    text = Faker::Lorem.characters(10)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('fr')
    Users::DetectLanguage.new.perform(user_id: user.id, text: text)
    user = account.users.where(id: user.id).first
    assert_equal 'fr', user.language
  end

  def test_hide_response_from_customer
    account = Account.current
    user = account.users.first
    account.launch(:hide_response_from_customer_feature)
    id = Faker::Lorem.characters(50)
    subject = 'Test Subject'
    params = default_params(id, subject)
    process_email = Helpdesk::ProcessEmail.new(params)
    note_params = process_email.safe_send(:build_note_params, account.tickets.first, { email: 'customfrom@test.com' }, User.first, false, '', '', '', '', [])
    assert_equal true, note_params[:private]
  ensure
    account.rollback(:hide_response_from_customer_feature)
  end

  # Try creating ticket if the message params does not contain "in-reply-to" which will be present only for replied/forwarded mails
  # Ticket requester will be the agent email if the feature is enabled.
  def test_create_ticket_with_composed_email_feature_enabled
    Account.any_instance.stubs(:composed_email_check_enabled?).returns(true)
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:attachments] = 0
    # sender of the mail should be the agent
    req_params[:from] = @agent_email
    req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name}<#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject\n-----\n"
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if 'from' field in message params is equal to the requestor in the ticket as this is a composed mail
    assert_equal req_params[:from], ticket_requestor.email
  end

  # If the feature is disabled, ticket requester will be parsed from quoted mail text
  def test_create_ticket_with_composed_email_feature_disabled
    Account.any_instance.stubs(:composed_email_check_enabled?).returns(false)
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:attachments] = 0
    # sender of the mail should be the agent
    req_params[:from] = @agent_email
    req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name}<#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject\n-----\n"
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if the ticket requester is equal to email parsed from the quoted message since the launch-party feature is disabled
    assert_equal @parse_email, ticket_requestor.email
  end

  # Try creating ticket if the message params contains "in-reply-to". This should be irregardless of the feature.
  def test_create_ticket_with_forwarded_email
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:in_reply_to] = @in_reply_to
    req_params[:attachments] = 0
    # sender of the mail should be the agent
    req_params[:from] = @agent_email
    req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name}<#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject\n-----\n"
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if 'from' field in message params is not equal to the requestor in the ticket as this is a forwarded mail
    # Assuming that the toggle for :disable_agent_forward is false
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_eng
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "This is a forwarded message!\n\n---------- Forwarded message ---------\nFrom: #{@parse_name} <#{@parse_email}>\nDate: Thu, Apr 9, 2020 at 6:57 PM\nSubject: Re: demo testing 5\nTo: Rio <palermo@gmail.com>, <qwerty1234@yahoo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>\n\n\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_esp
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "junto a los mensajes enviados a mi direcciMostrarnnn (no a una lista de distribuci Unannn), y ) al lado duna flecha doble ( flecha (\n\n\nEl vie., 24 abr. 2020 a las 11:37, #{@parse_name} (<#{@parse_email}>) escribi:::\nFYI please.\nOn Sat, Apr 11, 2020 at 10:26 AM Rio <palermo@gmail.com> wrote:\ntesting 2\nOn Sat, Apr 11, 2020 at 10:25 AM qwerty <qwerty1234@gmail.com> wrote:\ntesting 1"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_esp
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "de distribuci Unannn), y ) al lado duna flecha doble ( flecha (\\n\\n\\nEl vie., 24 abr. 2020 a las 11:37,\n\n---------- Forwarded message ---------\nDe: #{@parse_name} <#{@parse_email}>\nDate: vie., 24 abr. 2020 a las 11:37\nSubject: Re: testing reply-to 1\nTo: Rio <palermo@gmail.com>\nCc: <qwerty1234@yahoo.com>, Lisbon Tokyo <pamelamay20@gmail.com>, <support@angrynerds1993.freshpo.com>\n\n\nFYI please.\nOn Sat, Apr 11, 2020 at 10:26 AM Rio <palermo@gmail.com> wrote:\ntesting 2\nOn Sat, Apr 11, 2020 at 10:25 AM qwerty <qwerty1234@gmail.com> wrote:\ntesting 1"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_deutshe
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "testemailB dnjdndf. dknfjan\nAm Fr., 24. Apr. 2020 um 13:05B Uhr schrieb #{@parse_name} <#{@parse_email}>:\nPFA. Thanks & Regards\nOn Wed, Apr 8, 2020 at 12:08 PM John Wick <qwerty1234@outlook.com> wrote:\nPlease check.From: John Wick <qwerty1234@outlook.com>\nSent: 08 April 2020 11:46\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>; support@angrynerds1993.freshpo.com <support@angrynerds1993.freshpo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; Lisbon Tokyo <pamelamay20@gmail.com>\nSubject: Re: Another test mailB Please look into it.\nRegards,V"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_deutshe
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "forwajdnd dnfsjf\n\n---------- Forwarded message ---------\nVon: #{@parse_name} <#{@parse_email}>\nDate: Fr., 24. Apr. 2020 um 13:05B Uhr\nSubject: Re: Another test mail\nTo: John Wick <qwerty1234@outlook.com>\nCc: Rio <palermo@gmail.com>, LISBON MUMBAI <pamela.stockholm@test987.edu>, Lisbon Tokyo <pamelamay20@gmail.com>, <support@angrynerds1993.freshpo.com>\n\n\nPFA. Thanks & Regards\nAm Fr., 24. Apr. 2020 um 13:05B Uhr schrieb qwerty <qwerty1234@gmail.com>:\nPlease check.From: John Wick <qwerty1234@outlook.com>\nSent: 08 April 2020 11:46\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>; support@angrynerds1993.freshpo.com <support@angrynerds1993.freshpo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; Lisbon Tokyo <pamelamay20@gmail.com>\nSubject: Re: Another test mailB Please look into it.\nRegards,V"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_dutch
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "djnsnvsjB dgnnksvB djns\nOp za 11 apr. 2020 om 14:43 schreef #{@parse_name} <#{@parse_email}>:\nAnother hi\nOn Sat, Apr 11, 2020 at 2:42 PM John Wick <qwerty1234@outlook.com> wrote:\nSay hiFrom: Denver ghuio <bogotacena@outlook.com>\nSent: 11 April 2020 13:49\nTo: qwerty1234@outlook.com <qwerty1234@outlook.com>\nSubject: TestB Hi"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_dutch
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "dnfjsnfB djfnsjf\n\n---------- Forwarded message ---------\nVan: #{@parse_name} <#{@parse_email}>\nDate: za 11 apr. 2020 om 14:43\nSubject: Re: Test\nTo: John Wick <qwerty1234@outlook.com>\nCc: palermo@gmail.com <palermo@gmail.com>, pamela.stockholm@test987.edu <pamela.stockholm@test987.edu>\n\n\nAnother hi\nOn Sat, Apr 11, 2020 at 2:42 PM John Wick <qwerty1234@outlook.com> wrote:\nSay hiFrom: Denver ghuio <bogotacena@outlook.com>\nSent: 11 April 2020 13:49\nTo: qwerty1234@outlook.com <qwerty1234@outlook.com>\nSubject: TestB"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_french
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "djnfsf jdnf Le\nLeB sam. 11 avr. 2020 C B 10:43, #{@parse_name} <#{@parse_email}> a C)critB :\ndemo"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_french
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "kdfknsf\n\n---------- Forwarded message ---------\nDe : #{@parse_name} <#{@parse_email}>\nDate: sam. 11 avr. 2020 C B 10:43\nSubject: test\nTo: qwerty <qwerty1234@gmail.com>\n\n\ndemo"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_portuguese
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "dfadf\n#{@parse_name} <#{@parse_email}> escreveu no dia sC!bado, 11/04/2020 C (s) 11:01:\n yes this is demo\n On Saturday, 11 April 2020, 10:44:01 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n demo"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_forwards_portuguese
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "dfsfsdfdsf\ndfdff\n---------- Forwarded message ---------\nDe: #{@parse_name} <#{@parse_email}>\nDate: sC!bado, 11/04/2020 C (s) 11:01\nSubject: Re: test\nTo: qwerty <qwerty1234@gmail.com>\n\n\n yes this is demo\n On Saturday, 11 April 2020, 10:44:01 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n demo"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_oth_locale
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "dnfdjn njfiw VypnDjnsjdndsns pre jazyk: anglitinaB \nne 12. 4. 2020 oB 11:12 #{@parse_name} <#{@parse_email}> napC-sal(a):\n how abt this ?\n On Sunday, 12 April 2020, 11:10:32 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n checking\nOn Sun, Apr 12, 2020 at 10:59 AM qwerty <qwerty1234@gmail.com> wrote:\nhiiii\nOn Sun, Apr 12, 2020 at 10:47 AM John Wick <qwerty1234@outlook.com> wrote:\nplease check.From: John Wick <qwerty1234@outlook.com>\nSent: 09 April 2020 15:10\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; bogotacena@outlook.com <bogotacena@outlook.com>\nSubject: Re: test forward featureB Reply no. 2From: Rio <palermo@gmail.com>\nSent: 09 April 2020 15:09\nTo: John Wick <qwerty1234@outlook.com>\nCc: Lisbon Tokyo <pamelamay20@gmail.com>; LISBON MUMBAI <pamela.stockholm@test987.edu>; bogotacena@outlook.com <bogotacena@outlook.com>\nSubject:fdfdf"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng_feature_disabled
    Account.any_instance.stubs(:parse_replied_email_enabled?).returns(false)
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    from_name = Faker::Name.name
    from_email = Faker::Internet.email
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\nFrom: #{from_name} <#{from_email}> check 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert that if the launch-party feature is disabled, the emails replied from gmail client is not parsed. Insted it parses old quoted message from the mail thread.
    assert_equal from_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng_line_break1
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}\n> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng_line_break2
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <\n#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng_line_break3
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} \n<#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end

  def test_create_ticket_agent_replies_eng_line_break4
    req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
    test_name = Faker::Name.name
    req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{test_name}\n#{@parse_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <\npalermo@gmail.com> wrote:\ncheck 1. testing 5"
    req_params[:in_reply_to] = @in_reply_to
    req_params[:from] = @agent_email
    email_handler = Helpdesk::ProcessEmail.new(req_params)
    ticket_creation_status = email_handler.perform(@parsed_to_email)
    ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
    ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
    # Assert if ticket requester is equal to the email parsed from the quoted message.
    assert_equal @parse_email, ticket_requestor.email
  end
end
