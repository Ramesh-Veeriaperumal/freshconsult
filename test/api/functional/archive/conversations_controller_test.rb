require_relative '../../test_helper'
['social_tickets_creation_helper'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'sidekiq/testing'

class Archive::ConversationsControllerTest < ActionController::TestCase
  include ArchiveTicketTestHelper
  include ConversationsTestHelper
  include ApiTicketsTestHelper
  include TicketHelper
  include SocialTicketsCreationHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago
  ARCHIVE_TICKETS_COUNT = 5

  def setup
    super
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    ArchiveNoteConfig[current_shard] = 0
    @account.make_current
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    create_archive_ticket
  end

  def teardown
    cleanup_archive_ticket(@archive_ticket, {conversations: true})
  end

  def test_ticket_conversations
    archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
    note_json = archive_ticket.notes.conversations.map do |note|
      payload = note_pattern({}, note)
      archive_note_payload(note, payload)
    end
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    assert_response 200
    match_json(note_json)
  end

  def test_ticket_conversations_with_archive_notes
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    archive_note_config_prev = ArchiveNoteConfig[current_shard]
    ArchiveNoteConfig[current_shard] = (Helpdesk::ArchiveTicket.last ? Helpdesk::ArchiveTicket.last.id : 1) + 1000

    stub_archive_note_assoc(@archive_note_association) do 
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      result_pattern = []
      archive_ticket.notes.conversations.map do |note|
        archive_note = create_archive_note(note, archive_ticket)
        result_pattern << archive_note_payload(archive_note, archive_note_pattern({}, archive_note))
      end
      get :ticket_conversations, controller_params(id: archive_ticket.display_id)
      assert_response 200
      match_json(result_pattern)
    end
    ArchiveNoteConfig[current_shard] = archive_note_config_prev
  end

  def test_ticket_conversations_with_pagination
    archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)

    get :ticket_conversations, controller_params(id: archive_ticket.display_id, page: '1', per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_ticket_conversations_with_pagination_exceeds_limit
    archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)

    get :ticket_conversations, controller_params(id: archive_ticket.display_id, per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_without_archive_feature
    archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
    Account.any_instance.stubs(:enabled_features_list).returns([])
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    assert_response 403
    Account.any_instance.unstub(:enabled_features_list)
  end

  def test_archive_ticket_conversations_with_freshcaller_call
    Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
    archive_ticket = create_archive_ticket({ freshcaller_call: true })
    Account.current.add_feature(:archive_tickets)
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    archive_ticket.archive_notes.reload
    assert_response 200
    conversations = JSON.parse(response.body)
    assert (conversations.any? { |note| note.key?('freshcaller_call') })
  ensure
    Account.any_instance.unstub(:freshcaller_enabled?)
  end

  def test_archive_twitter_ticket_with_restricted_twitter_conversations
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true)
    archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
    note_json = archive_ticket.notes.conversations.map do |note|
      payload = note_pattern({}, note)
      archive_note_payload(note, payload)
    end
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    assert_response 200
    match_json(note_json)
  ensure
    CustomRequestStore.store[:private_api_request] = true
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_archive_twitter_ticket_with_unrestricted_twitter_conversations
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true)
    archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
    note_json = archive_ticket.notes.conversations.map do |note|
      payload = note_pattern({}, note)
      archive_note_payload(note, payload)
    end
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    assert_response 200
    match_json(note_json)
  ensure
    CustomRequestStore.store[:private_api_request] = true
  end

  def test_archive_ticket_with_restricted_twitter_archive_notes
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:private_api_request] = false
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    archive_note_config_prev = ArchiveNoteConfig[current_shard]
    ArchiveNoteConfig[current_shard] = (Helpdesk::ArchiveTicket.last ? Helpdesk::ArchiveTicket.last.id : 1) + 1000

    create_archive_ticket(twitter_ticket: true)
    stub_archive_note_assoc(@archive_note_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      result_pattern = []
      archive_ticket.notes.conversations.map do |note|
        archive_note = create_archive_note(note, archive_ticket)
        result_pattern << archive_note_payload(archive_note, archive_note_pattern({}, archive_note))
      end
      get :ticket_conversations, controller_params(id: archive_ticket.display_id)
      assert_response 200
      match_json(result_pattern)
    end
    ArchiveNoteConfig[current_shard] = archive_note_config_prev
  ensure
    CustomRequestStore.store[:private_api_request] = true
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_archive_ticket_with_unrestricted_twitter_archive_notes
    CustomRequestStore.store[:private_api_request] = false
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    archive_note_config_prev = ArchiveNoteConfig[current_shard]
    ArchiveNoteConfig[current_shard] = (Helpdesk::ArchiveTicket.last ? Helpdesk::ArchiveTicket.last.id : 1) + 1000

    create_archive_ticket(twitter_ticket: true)
    stub_archive_note_assoc(@archive_note_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      result_pattern = []
      archive_ticket.notes.conversations.map do |note|
        archive_note = create_archive_note(note, archive_ticket)
        result_pattern << archive_note_payload(archive_note, archive_note_pattern({}, archive_note))
      end
      get :ticket_conversations, controller_params(id: archive_ticket.display_id)
      assert_response 200
      match_json(result_pattern)
    end
    ArchiveNoteConfig[current_shard] = archive_note_config_prev
  ensure
    CustomRequestStore.store[:private_api_request] = true
  end

  private

    def create_archive_ticket(options = {})
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_conversations: true,
        create_association: true,
        create_note_association: true,
        create_freshcaller_call: options[:freshcaller_call] || false,
        create_twitter_ticket: options[:twitter_ticket] || false,
        tweet_type: options[:twitter_ticket] ? options[:tweet_type] : nil
      )
      @account.archive_tickets.last
    end

    def archive_note_payload(note, payload)
      payload.merge!({
        source: note.source,
        from_email: note.from_email,
        cc_emails: note.cc_emails,
        bcc_emails: note.bcc_emails,
        cloud_files: []
      })
      payload
    end
end
