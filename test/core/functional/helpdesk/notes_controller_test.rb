require_relative '../../test_helper'
require 'sidekiq/testing'

Dir["#{Rails.root}/test/core/functional/helpdesk/conversation_test_cases/*.rb"].each { |file| require file }

class Helpdesk::NotesControllerTest < ActionController::TestCase
  include CoreTicketsTestHelper
  include DynamoTestHelper
  include LinkTicketAssertions
  include NoteTestHelper
  include NoteTestIntegrationsHelper
  include TicketConstants
  include CoreUsersTestHelper

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
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["email"], nil, CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_note_source_email_public
    customer_notification =  Delayed::Job.where(AGENT_REPLIED_STRING).all.count
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["email"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(AGENT_REPLIED_STRING).all.count
  end

  def test_email_note_agent_private
    agent_notification =  Delayed::Job.where(AGENT_NOTE_ADDED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["note"], nil, COMMENT_ADDED_UNIQ_STRING, PRIVATE, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal agent_notification+1, Delayed::Job.where(AGENT_NOTE_ADDED_UNIQ_STRING).all.count
  end

  def test_email_note_agent_public
    customer_notification =  Delayed::Job.where(AGENT_REPLIED_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["note"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count, Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification, Delayed::Job.where(AGENT_REPLIED_STRING).all.count
  end

  def test_note_source_email_public_agent_as_requestor
    customer_notification =  Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["email"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT, true)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_note_source_note_public_agent_as_requestor
    customer_notification =  Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
    notification_count ,ticket = create_ticket_add_agent_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["note"], nil, COMMENT_ADDED_UNIQ_STRING, PUBLIC, AGENT, true)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count , Delayed::Job.where(COMMENT_ADDED_UNIQ_STRING).all.count
    assert_equal customer_notification+1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_feedback_note_customer
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["feedback"], nil, CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::RESOLVED, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_public_note_email_status_change_customer
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::EMAIL, Account.current.helpdesk_sources.note_source_keys_by_token["email"], nil,
                                                        CUSTOMER_REPLIED_UNIQ_STRING, PUBLIC, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_private_note_contact_twitter_status_change_customer
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::TWITTER, Account.current.helpdesk_sources.note_source_keys_by_token["twitter"], nil,
                                                        CUSTOMER_REPLIED_UNIQ_STRING, PRIVATE, CUSTOMER)
    assert_equal Helpdesk::Ticketfields::TicketStatus::OPEN, ticket.status
    assert_equal notification_count + 1, Delayed::Job.where(CUSTOMER_REPLIED_UNIQ_STRING).all.count
  end

  def test_private_note_contact_facebook_status_change_customer
    notification_count ,ticket = create_ticket_add_note(Helpdesk::Source::FACEBOOK, Account.current.helpdesk_sources.note_source_keys_by_token["facebook"], nil,
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

  def test_public_note_with_datetime_info
    Sidekiq::Testing.inline! do
      # Create a ticket and add an incoming note with datetime information
      # memcache will store the datatimeinfo & note id.
      if ! @account.launched?(:ner)
        @account.launch(:ner)
      end

      ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket"})
      note = create_note({:incoming => 1, :private => false, :body => "Lets meet at 5pm today", :body => "<div>Lets meet at 5pm today</div>"})
      keys = MemcacheKeys::NER_ENRICHED_NOTE % { :account_id => @account.id , :ticket_id => ticket.id }
      stored_data =  MemcacheKeys.get_from_cache(keys)

      assert_equal stored_data["datetimes"][0]["value"]["time"], "17:00:00"
      assert_equal stored_data["note_id"], note.id
    end
  end

  def test_public_note_without_datetime_info
    Sidekiq::Testing.inline! do

      if ! @account.launched?(:ner)
        @account.launch(:ner)
      end

      ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket"})

      keys = MemcacheKeys::NER_ENRICHED_NOTE % { :account_id => @account.id , :ticket_id => ticket.id }
      MemcacheKeys.delete_from_cache keys

      # An incoming note without datetime information -> memcache will not be updated.
      # Memcache will still have last incoming note's datetime info or nil (if there is none). 

      note = create_note({:incoming => 1, :private => false, :body => "This is sample note", :body => "<div>This is sample note</div>"})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data, nil
    end
  end

  def test_agent_note_with_datetime_info
    Sidekiq::Testing.inline! do
      user = add_test_agent

      if ! @account.launched?(:ner)
        @account.launch(:ner)
      end

      # create ticket as agent

      ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket", :requester_id => user.id})
      keys = MemcacheKeys::NER_ENRICHED_NOTE % { :account_id => @account.id , :ticket_id => ticket.id }
      MemcacheKeys.delete_from_cache keys

      # An outgoing agent note with datetime information -> memcache will not be updated.
      # Memcache will still have last incoming note's datetime info or nil (if there is none). 

      note = create_note({:incoming => 0, :private => false, :body => "Lets meet at 5pm today", :body => "<div>Lets meet at 5pm today</div>"})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data, nil
    end
  end

  def test_note_with_updated_datetime_info
    Sidekiq::Testing.inline! do
      user = add_new_user(@account)

      if ! @account.launched?(:ner)
        @account.launch(:ner)
      end

      # create ticket as customer
      ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket", :requester_id => user.id})
      keys = MemcacheKeys::NER_ENRICHED_NOTE % { :account_id => @account.id , :ticket_id => ticket.id }
      MemcacheKeys.delete_from_cache keys

      # customer incoming note with datetime information - datetime info will be stored in memcache

      note1 = create_note({:incoming => 1, :private => false, :body => "Lets meet at 5.30pm today", :body => "<div>Lets meet at 5.30pm today</div>", :user_id => user.id})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data["datetimes"][0]["value"]["time"], "17:30:00"
      assert_equal stored_data["note_id"], note1.id

      # customer incoming note without datetime information.
      # memcache will not be updated and retain the last incoming note's value (which is having datetime infomration)
      # Here, memcache will still be having note1's id & its date time info

      note2 = create_note({:incoming => 1, :private => false, :body => "This is sample note", :body => "<div>This is sample note</div>", :user_id => user.id})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data["datetimes"][0]["value"]["time"], "17:30:00"
      assert_not_match stored_data["note_id"], note2.id
      assert_equal stored_data["note_id"], note1.id

      # Agent's outgoing note with datetime information.
      # memcache will not be updated and retain the last incoming note's value (which is having datetime infomration)
      # Here, memcache will still be having note1's id & its date time info

      note3 = create_note({:incoming => 0, :private => false, :body => "Lets meet at 6.34pm today", :body => "<div>Lets meet at 6.34pm today</div>"})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data["datetimes"][0]["value"]["time"], "17:30:00"
      assert_not_match stored_data["note_id"], note3.id
      assert_equal stored_data["note_id"], note1.id

      # customer incoming note with datetime information - datetime info & note id will be updated in memcache.

      note4 = create_note({:incoming => 1, :private => false, :body => "Lets meet at 7.30pm today", :body => "<div>Lets meet at 7.30pm today</div>", :user_id => user.id})
      stored_data =  MemcacheKeys.get_from_cache(keys)
      assert_equal stored_data["datetimes"][0]["value"]["time"], "19:30:00"
      assert_equal stored_data["note_id"], note4.id
    end
  end
end