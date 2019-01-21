require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['tickets_test_helper.rb', 'conversations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class NotifyBroadcastMessagesTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include TicketHelper
  include ConversationsTestHelper

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

  def create_tracker_and_related_tickets(related_ticket_count = 1)
    tracker_ticket = create_tracker_ticket
    related_ticket_count.times do
      related_ticket = create_ticket
      link_to_tracker(related_ticket, tracker_ticket)
    end
    tracker_ticket
  end

  def test_broadcast_message_agent_notification_with_agents
    tracker_ticket = create_tracker_and_related_tickets(2)
    related_tickets = tracker_ticket.associated_subsidiary_tickets('tracker')
    related_tickets.each do |related_ticket|
      new_agent = add_test_agent(@account)
      related_ticket.update_attributes(responder_id: new_agent.id)
    end
    broadcast_note = create_broadcast_note(tracker_ticket.id)
    background_job_count_before = BroadcastMessages::NotifyAgent.jobs.size
    BroadcastMessages::NotifyBroadcastMessages.new.perform(tracker_display_id: tracker_ticket.display_id, broadcast_id: broadcast_note.id)
    background_job_count_after = BroadcastMessages::NotifyAgent.jobs.size
    assert_equal background_job_count_before + 2, background_job_count_after
  end

  def test_broadcast_message_agent_notification_with_watchers
    tracker_ticket = create_tracker_and_related_tickets
    related_ticket = tracker_ticket.associated_subsidiary_tickets('tracker')
    watcher_agent = add_test_agent(@account)
    add_watchers_to_ticket(@account, options = { ticket_id: related_ticket.first.id, agent_id: [watcher_agent.id] })
    broadcast_note = create_broadcast_note(tracker_ticket.id)
    background_job_count_before = BroadcastMessages::NotifyAgent.jobs.size
    BroadcastMessages::NotifyBroadcastMessages.new.perform(tracker_display_id: tracker_ticket.display_id, broadcast_id: broadcast_note.id)
    background_job_count_after = BroadcastMessages::NotifyAgent.jobs.size
    assert_equal background_job_count_before + 1, background_job_count_after
  end

  def test_broadcast_message_agent_notification_for_unassigned_ticket
    tracker_ticket = create_tracker_and_related_tickets
    broadcast_note = create_broadcast_note(tracker_ticket.id)
    background_job_count_before = BroadcastMessages::NotifyAgent.jobs.size
    BroadcastMessages::NotifyBroadcastMessages.new.perform(tracker_display_id: tracker_ticket.display_id, broadcast_id: broadcast_note.id)
    background_job_count_after = BroadcastMessages::NotifyAgent.jobs.size
    assert_equal background_job_count_before, background_job_count_after
  end

  def test_broadcast_message_agent_notification_with_exception
    assert_nothing_raised do
      tracker_ticket = create_tracker_and_related_tickets
      broadcast_note = create_broadcast_note(tracker_ticket.id)
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      BroadcastMessages::NotifyBroadcastMessages.new.perform(tracker_display_id: tracker_ticket.display_id, broadcast_id: broadcast_note.id)
      Account.any_instance.unstub(:tickets)
    end
  end
end
