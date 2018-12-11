require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class BulkTicketReplyTest < ActionView::TestCase
  include TicketHelper
  include UsersHelper
  include ControllerTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def create_spam_key
    key = "#{@agent.account_id}-#{@agent.id}"
    value = Time.now.to_i.to_s
    return "#{key}:#{value}"
  end

  def build_args(ticket_ids, user_id, spam_key)
    {
      "ids": ticket_ids,
      "helpdesk_note": {
        "private": false,
        "user_id": user_id,
        "source": 0,
        "note_body_attributes": {
          "body_html": "<div>test</div>",
        },
        "inline_attachment_ids": [],
      },
      "spam_key": spam_key,
      "cloud_files": []
    }
  end

  def create_args
    ticket_ids = create_n_tickets(2)
    user_id = @agent.id
    spam_key = create_spam_key
    args = build_args(ticket_ids, user_id, spam_key)
    return ActiveSupport::HashWithIndifferentAccess.new(args)
  end

  def create_args_without_spam_key
    ticket_ids = create_n_tickets(2)
    user_id = @agent.id
    args = build_args(ticket_ids, user_id, spam_key)
    return ActiveSupport::HashWithIndifferentAccess.new(args)
  end

  def test_bulk_ticket_reply_worker_runs
    args = create_args
    Tickets::BulkTicketReply.new.perform(args)
    assert_equal 0, Tickets::BulkTicketReply.jobs.size
  end

  def test_bulk_ticket_reply_worker_updates_tickets
    args = create_args
    Redis.stubs(:perform_redis_op).returns(true)
    old_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    Tickets::BulkTicketReply.new.perform(args)
    @account.reload
    new_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    assert_equal 0, Tickets::BulkTicketReply.jobs.size
    assert_equal old_count + 1, new_count
  end

  def test_bulk_ticket_reply_worker_errors_out
    args = create_args
    old_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    Helpdesk::BulkReplyTickets.any_instance.stubs(:act).raises(Exception.new('test'))
    Tickets::BulkTicketReply.new.perform(args)
    @account.reload
    new_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    assert_equal 0, Tickets::BulkTicketReply.jobs.size
    assert_equal old_count, new_count
  rescue Exception => e
    assert_equal e.message, 'test'
  end

  def test_ensure_errors_out_on_redis_fail
    args = create_args_without_spam_key
    old_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    Tickets::BulkTicketReply.new.perform(args)
    @account.reload
    new_count = @account.tickets.where(display_id: args["ids"].first).first.notes.count
    assert_equal 0, Tickets::BulkTicketReply.jobs.size
  rescue Exception => e
  end
end
