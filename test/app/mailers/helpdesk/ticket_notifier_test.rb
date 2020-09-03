require_relative '../../../test_helper.rb'
require_relative '../../../api/helpers/test_class_methods.rb'
require_relative '../../../core/helpers/account_test_helper.rb'
require_relative '../../../core/helpers/controller_test_helper.rb'
require_relative '../../../core/helpers/users_test_helper.rb'
require_relative '../../../core/helpers/tickets_test_helper.rb'
require_relative '../../../core/helpers/note_test_helper.rb'
['ticket_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join("spec/support/#{file}") }

class TicketNotifierTest < ActionMailer::TestCase
  include AccountTestHelper
  include ControllerTestHelper
  include CoreUsersTestHelper
  include CoreTicketsTestHelper
  include TicketHelper
  include UsersHelper
  include NoteTestHelper

  def setup
    get_agent
    @ticket = create_ticket
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    super
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_email_gets_sent_without_no_agent_when_responder_is_nil
    Account.any_instance.stubs(:features?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    email = Helpdesk::TicketNotifier.deliver_notify_outbound_email(@ticket)
    Account.any_instance.unstub(:features?)
    assert_equal true, email[:from].value[0].include?("Test Account")
  end

  def test_email_gets_sent_with_agent_name_when_responder_is_not_nil
    user = User.first
    @ticket.responder = user
    Account.any_instance.stubs(:features?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    email = Helpdesk::TicketNotifier.deliver_notify_outbound_email(@ticket)
    Account.any_instance.unstub(:features?)
    assert_equal true, email[:from].value[0].include?(user.name)
  end

  def test_agent_assign_email_notification_go_for_ticket
    agent = add_test_agent(@account)
    ticket = create_ticket({ email: 'sample@freshdesk.com', source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:email], responder_id: agent.id })
    enable_agent_assign_notification
    Mail::Message.any_instance.expects(:deliver).once
    Helpdesk::TicketNotifier.notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT, ticket)
  end

  def enable_agent_assign_notification
    e_notification = @account.email_notifications.find_by_notification_type(EmailNotification::TICKET_ASSIGNED_TO_AGENT)
    e_notification.update_attributes({ agent_notification: true })
  end

  def test_ticket_reply_with_secure_attachments
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    note = create_note_with_attachments(ticket_id: ticket.id, user_id: agent.id)
    options = {
      include_cc: false,
      send_survey: false,
      quoted_text: note.quoted_text,
      include_surveymonkey_link: false
    }
    from_email = Faker::Internet.email
    to_email = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_email
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    @account.add_feature(:private_inline)
    @account.stubs(:secure_attachments_enabled?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.reply(ticket, note, options)
    assert_equal mail_message.to.first, to_email.first
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      attachment_url = note.attachments.first.inline_url
      assert html_part.include?(attachment_url)
    end
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    if text_part.present?
      attachment_url = note.attachments.first.inline_url
      assert text_part.include?(attachment_url)
    end
  ensure
    note.destroy
    ticket.destroy
    agent.destroy
    @account.revoke_feature(:private_inline)
    @account.unstub(:secure_attachments_enabled?)
  end

  def test_ticket_forward_with_secure_attachments
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    num_of_files = 3
    note = create_note_with_multiple_attachments(num_of_files: num_of_files, ticket_id: ticket.id, user_id: agent.id)
    options = {
      include_cc: false,
      send_survey: false,
      quoted_text: note.quoted_text,
      include_surveymonkey_link: false
    }
    from_email = Faker::Internet.email
    to_emails = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_emails
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    @account.add_feature(:private_inline)
    @account.stubs(:secure_attachments_enabled?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.forward(ticket, note, options)
    assert_equal mail_message.to.first, to_emails.first
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      attachment_url = note.attachments.first.inline_url
      assert html_part.include?(attachment_url)
      assert_equal note.attachments.count, num_of_files
    end
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    if text_part.present?
      attachment_url = note.attachments.first.inline_url
      assert text_part.include?(attachment_url)
      assert_equal note.attachments.count, num_of_files
    end
  ensure
    note.destroy
    ticket.destroy
    agent.destroy
    @account.revoke_feature(:private_inline)
    @account.unstub(:secure_attachments_enabled?)
  end

  def test_ticket_reply_to_forward_with_secure_attachments
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    num_of_files = 3
    note = create_note_with_multiple_attachments(num_of_files: num_of_files, ticket_id: ticket.id, user_id: agent.id)
    from_email = Faker::Internet.email
    to_email = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_email
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    @account.add_feature(:private_inline)
    @account.stubs(:secure_attachments_enabled?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.deliver_reply_to_forward(ticket, note)
    assert_equal mail_message.to.first, to_email.first
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      attachment_url = note.attachments.first.inline_url
      assert html_part.include?(attachment_url)
      assert_equal note.attachments.count, num_of_files
    end
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    if text_part.present?
      attachment_url = note.attachments.first.inline_url
      assert text_part.include?(attachment_url)
      assert_equal note.attachments.count, num_of_files
    end
  ensure
    note.destroy
    ticket.destroy
    agent.destroy
    @account.revoke_feature(:private_inline)
    @account.unstub(:secure_attachments_enabled?)
  end

  def test_notify_outbound_email_with_secure_attachments
    agent = add_test_agent(@account)
    num_of_files = 3
    ticket = create_ticket_with_multiple_attachments(num_of_files: num_of_files, requester_id: agent.id)
    @account.add_feature(:private_inline)
    @account.stubs(:secure_attachments_enabled?).returns(true)
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.notify_outbound_email(ticket)
    assert_equal mail_message.to.first, agent.email
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      attachment_url = ticket.all_attachments.first.inline_url
      assert html_part.include?(attachment_url)
      assert_equal ticket.all_attachments.count, num_of_files
    end
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    if text_part.present?
      attachment_url = ticket.all_attachments.first.inline_url
      assert text_part.include?(attachment_url)
      assert_equal ticket.all_attachments.count, num_of_files
    end
  ensure
    ticket.destroy
    agent.destroy
    @account.revoke_feature(:private_inline)
    @account.unstub(:secure_attachments_enabled?)
  end

  def test_email_notification_with_secure_attachments
    agent = add_test_agent(@account)
    num_of_files = 3
    ticket = create_ticket_with_multiple_attachments(num_of_files: num_of_files, requester_id: agent.id)
    @account.add_feature(:private_inline)
    @account.stubs(:secure_attachments_enabled?).returns(true)
    params = { :ticket => ticket,
               :notification_type => EmailNotification::NEW_TICKET_CC,
               :receips => agent.email,
               :email_body_plain => Faker::Lorem.characters(10),
               :email_body_html => Faker::Lorem.characters(10),
               :subject => Faker::Lorem.characters(10),
               :attachments => ticket.attachments }
    mail_message = Helpdesk::TicketNotifier.email_notification(params)
    assert_equal mail_message.to.first, agent.email
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      attachment_url = ticket.attachments.first.inline_url
      assert html_part.include?(attachment_url)
      assert_equal ticket.attachments.count, num_of_files
    end
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    if text_part.present?
      attachment_url = ticket.attachments.first.inline_url
      assert text_part.include?(attachment_url)
      assert_equal ticket.attachments.count, num_of_files
    end
  ensure
    ticket.destroy
    agent.destroy
    @account.revoke_feature(:private_inline)
    @account.unstub(:secure_attachments_enabled?)
  end

  def test_email_reply_call_deliver_bang_method
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    note = create_note
    options = {
      include_cc: false,
      send_survey: false,
      quoted_text: note.quoted_text,
      include_surveymonkey_link: false
    }
    from_email = Faker::Internet.email
    to_email = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_email
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.reply(ticket, note, options)
    assert_equal mail_message.to.first, to_email.first
  end

  def test_email_forward_call_deliver_bang_method
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    note = create_note
    options = {
      include_cc: false,
      send_survey: false,
      quoted_text: note.quoted_text,
      include_surveymonkey_link: false
    }
    from_email = Faker::Internet.email
    to_emails = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_emails
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.forward(ticket, note, options)
    assert_equal mail_message.to.first, to_emails.first
  end

  def test_email_reply_to_forward_call_deliver_bang_method
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    note = create_note
    from_email = Faker::Internet.email
    to_email = [Faker::Internet.email]
    note.schema_less_note.to_emails = to_email
    note.schema_less_note.from_email = from_email
    note.schema_less_note.save
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.deliver_reply_to_forward(ticket, note)
    assert_equal mail_message.to.first, to_email.first
  end

  def test_email_notify_outbound_call_deliver_bang_method
    agent = add_test_agent(@account)
    ticket = create_ticket(requester_id: agent.id)
    Mail::Message.any_instance.expects(:deliver!).once
    mail_message = Helpdesk::TicketNotifier.notify_outbound_email(ticket)
    assert_equal mail_message.to.first, agent.email
  end
end
