require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class UndoSendWorkerTest < ActionView::TestCase
  include UsersTestHelper
  include ApiTicketsTestHelper

  def setup
    @account = Account.first.make_current
    @account.add_feature(:undo_send)
    @customer = Account.current.users.first
  end

  def teardown
    @account.revoke_feature(:undo_send)
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
