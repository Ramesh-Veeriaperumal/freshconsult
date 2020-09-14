require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'agent_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

Sidekiq::Testing.fake!

class UndoSendWorkerTest < ActionView::TestCase
  include NoteTestHelper
  include AccountTestHelper
  include CoreUsersTestHelper
  include AgentHelper
  include ApiTicketsTestHelper
  include CoreTicketsTestHelper

  def setup
    @account = Account.first || create_new_account
    @account.make_current
    @customer = Account.current.users.first
    @customer.make_current
    @ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
  end

  def undo_send_args(ticket)
    {
      account_id: Account.current.id,
      user_id: @customer.id,
      ticket_id: ticket.display_id,
      note_basic_attributes:
        {
          'id' => nil,
          'body' => nil,
          'user_id' => @customer.id,
          'source' => 0,
          'incoming' => false,
          'private' => false,
          'created_at' => Time.now.utc,
          'updated_at' => nil,
          'deleted' => false,
          'notable_id' => ticket.display_id,
          'notable_type' => 'Helpdesk::Ticket',
          'account_id' => Account.current.id,
          'body_html' => nil
        },
      note_schema_less_associated_attributes:
        {
          from_email: reply_note_params_hash[:from_email],
          to_emails: [@customer.email],
          cc_emails: [],
          bcc_emails: [],
          header_info: nil,
          category: nil,
          response_time_in_seconds: nil,
          response_time_by_bhrs: nil,
          email_config_id: 1,
          subject: nil,
          last_modified_user_id: nil,
          last_modified_timestamp: nil,
          sentiment: nil,
          dynamodb_range_key: nil,
          failure_count: nil,
          import_id: nil,
          support_email: reply_note_params_hash[:from_email],
          changes_for_observer: nil,
          disable_observer_rule: nil,
          nscname: nil,
          disable_observer: nil,
          send_survey: nil,
          include_surveymonkey_link: nil,
          quoted_text: nil,
          skip_notification: nil,
          last_note_id: ticket.notes.last.id
        },
      attachment_details: [],
      inline_attachment_details: [],
      publish_solution_later: nil
    }
  end

  def reply_note_params_hash
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    email_config = @account.email_configs.where(active: true).first || create_email_config
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
    params_hash
  end

  def create_attachment_for_account(requester)
    attachment = @account.attachments.new
    attachment.description = 'abcx'
    attachment.attachable_id = requester.id
    attachment.attachable_type = 'Ticket::Inline'
    attachment.content_file_name = 'testattach'
    attachment.content_content_type = 'text/binary'
    attachment.content_file_size = 80
    attachment.save
    attachment
  end

  def test_undo_send_worker_publish_solution_later
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    undo_args = undo_send_args(ticket)
    undo_args[:publish_solution_later] = true
    args = HashWithIndifferentAccess.new(undo_args)
    Tickets::UndoSendWorker.new.perform(args)
    kbase = Account.current.solution_articles.last
    assert_equal ticket.subject, kbase.title
  end

  def test_undo_send_worker_with_save_exception
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    args = HashWithIndifferentAccess.new(undo_send_args(ticket))
    old_notes_count = ticket.notes.count
    Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
    Tickets::UndoSendWorker.new.perform(args)
    Helpdesk::Note.any_instance.unstub(:save_note)
    assert_equal old_notes_count, ticket.reload.notes.count
  end

  def test_undo_send_worker_with_exception
    Account.any_instance.stubs(:tickets).raises(RuntimeError)
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    args = HashWithIndifferentAccess.new(undo_send_args(ticket))
    old_notes_count = ticket.notes.count
    assert_raises(RuntimeError) do
      Tickets::UndoSendWorker.new.perform(args)
    end
    Account.any_instance.unstub(:tickets)
    assert_equal old_notes_count, ticket.reload.notes.count
  end

  def test_undo_send_worker_ticket_subject
    ticket_hash = ticket_params_hash
    ticket_hash[:subject] = 'a'
    ticket_hash[:requester_id] = @customer.id
    ticket = create_ticket(ticket_hash)
    create_normal_reply_for(ticket)
    undo_args = undo_send_args(ticket)
    undo_args[:publish_solution_later] = true
    args = HashWithIndifferentAccess.new(undo_args)
    Tickets::UndoSendWorker.new.perform(args)
    kbase = Account.current.solution_articles.last
    assert_equal I18n.t('undo_send_solution_error', ticket_display_id: ticket.display_id), kbase.title
  end

  def test_undo_send_worker_attachments
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    undo_args = undo_send_args(ticket)
    att = create_attachment_for_account(@customer)
    inline_att = create_attachment_for_account(@customer)
    undo_args[:attachment_details] = [att.id]
    undo_args[:inline_attachment_details] = [inline_att.id]
    args = HashWithIndifferentAccess.new(undo_args)
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal ticket.notes.last.inline_attachment_ids, undo_args[:inline_attachment_details]
    assert_equal ticket.notes.last.attachments.first, att
  end

  def test_undo_send_reply
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    args = HashWithIndifferentAccess.new(undo_send_args(ticket))
    old_notes_count = ticket.notes.count
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal 0, ::Tickets::UndoSendWorker.jobs.size
    assert_equal old_notes_count + 1, ticket.reload.notes.count
  end

  def test_undo_reply_with_blank_ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    Helpdesk::Ticket.any_instance.stubs(:blank?).returns(true)
    old_notes_count = ticket.notes.count
    args = HashWithIndifferentAccess.new(undo_send_args(ticket))
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal old_notes_count, ticket.reload.notes.count
  end

  def test_undo_reply_with_undo_send
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    create_normal_reply_for(ticket)
    Helpdesk::Ticket.any_instance.stubs(:blank?).returns(true)
    old_notes_count = ticket.notes.count
    args = HashWithIndifferentAccess.new(undo_send_args(ticket))
    Tickets::UndoSendWorker.any_instance.stubs(:get_undo_option).returns('false')
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal old_notes_count, ticket.reload.notes.count
  end

  def test_post_to_forum_topic
    ticket = new_ticket_from_forum_topic(requester_id: @customer.id)
    create_normal_reply_for(ticket)
    old_posts_count = ticket.ticket_topic.topic.posts.count
    args = HashWithIndifferentAccess.new(undo_send_args(ticket).merge(post_to_forum_topic: true))
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal 0, ::Tickets::UndoSendWorker.jobs.size
    new_posts_count = ticket.reload.ticket_topic.topic.posts.count
    assert_equal old_posts_count + 1, new_posts_count
  end
end
