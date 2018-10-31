require_relative '../../test_helper'
require 'sidekiq/testing'

class Archive::ConversationsControllerTest < ActionController::TestCase
  include ArchiveTicketTestHelper
  include ConversationsTestHelper
  include TicketsTestHelper
  include TicketHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago
  ARCHIVE_TICKETS_COUNT = 5

  def setup
    super
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    ArchiveNoteConfig[current_shard] = 0
    @account.make_current
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(
      created_at: TICKET_UPDATED_DATE,
      updated_at: TICKET_UPDATED_DATE,
      create_conversations: true, 
      create_association: true,
      create_note_association: true
    )
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
    @account.features.archive_tickets.destroy
    get :ticket_conversations, controller_params(id: archive_ticket.display_id)
    assert_response 403
  end

  private

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
