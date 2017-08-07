require_relative '../../test_helper'
require 'sidekiq/testing'

Dir["#{Rails.root}/test/core/functional/helpdesk/conversation_test_cases/*.rb"].each { |file| require file }

class Helpdesk::NotesControllerTest < ActionController::TestCase
  include TicketsTestHelper
  include DynamoTestHelper
  include LinkTicketAssertions
  include NoteTestHelper
  include NoteTestIntegrationsHelper
  include TicketConstants
  include UsersTestHelper

  def setup
    super
    login_admin
    Sidekiq::Testing.inline!
  end

  def teardown
    super
    Sidekiq::Testing.disable!
  end

  def test_delete_broadcast_note
    enable_adv_ticketing(:link_tickets) do
      related_ticket_ids = create_link_tickets
      tracker = Helpdesk::Ticket.last
      broadcast_note = create_broadcast_note(:ticket_id => tracker.id)
      stub_ticket_associates(related_ticket_ids, tracker) do
        delete :destroy, {:id => broadcast_note.id,:ticket_id => tracker.display_id}
        assert tracker.notes.broadcast_notes.present?
        assert_present @account.broadcast_messages.where(:tracker_display_id => tracker.display_id)
      end
    end
  end


  def test_private_note_contact_integrations_no_status_change
    notification_count ,ticket = create_ticket_add_note(nil, nil, nil, COMMENT_ADDED_UNIQ_STRING, PRIVATE, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
  end



  def test_public_note_contact_integrations_status_change
    notification_count ,ticket = create_ticket_add_note(nil, nil, nil, CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end


  def test_email_note_customer
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"], nil, CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_note_source_email_public
    customer_notification =  Delayed::Job.where(AGENT_REPLIED_STRING).all.count
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(AGENT_REPLIED_STRING).all.count
  end

  def test_email_note_agent_private
    agent_notification =  Delayed::Job.where(AGENT_NOTE_ADDED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], nil, COMMENT_ADDED_UNIQ_STRING, PRIVATE, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal agent_notification+1, Delayed::Job.where(AGENT_NOTE_ADDED_UNIQ_STRING).all.count
  end

  def test_email_note_agent_public
    customer_notification =  Delayed::Job.where(AGENT_REPLIED_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification, Delayed::Job.where(AGENT_REPLIED_STRING).all.count
  end

  def test_note_source_email_public_agent_as_requestor
    customer_notification =  Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT, true)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_note_source_note_public_agent_as_requestor
    customer_notification =  Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT, true)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_feedback_note_customer
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"], nil, CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_public_note_email_status_change_customer
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["email"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"], nil,
                                                        CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_private_note_contact_twitter_status_change_customer
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["twitter"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["twitter"], nil,
                                                        CUSTOMER_REPLIED_UNIQ_STRING, PRIVATE, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_private_note_contact_facebook_status_change_customer
    notification_count ,ticket = create_ticket_add_note(SOURCE_KEYS_BY_TOKEN["facebook"], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"], nil,
                                                        CUSTOMER_REPLIED_UNIQ_STRING, PRIVATE, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end



  def test_private_note_agent_integrations_no_status_change_agent
    notification_count ,ticket = create_ticket_add_note(nil, nil, nil, COMMENT_ADDED_UNIQ_STRING, PRIVATE, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
  end

  def test_public_note_agent_integrations_no_status_change_agent
    notification_count ,ticket = create_ticket_add_note(nil, nil, nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
  end

  def test_private_note_agent_integrations_no_status_change_third_party
    notification_count ,ticket = create_ticket_add_note(nil, nil, Helpdesk::Note::CATEGORIES[:third_party_response], COMMENT_ADDED_UNIQ_STRING, PRIVATE, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
  end

end