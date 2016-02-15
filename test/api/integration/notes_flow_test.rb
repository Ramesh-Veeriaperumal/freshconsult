require_relative '../test_helper'

class NotesFlowTest < ActionDispatch::IntegrationTest
  include NoteHelper

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def test_caching_when_updating_note_body
    skip_bullet do
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
      parent_ticket = ticket
      enable_cache do
        get "/api/v2/tickets/#{parent_ticket.display_id}/notes", nil, @write_headers
        note.note_body.body = 'Test update note body'
        note.save
        get "/api/v2/tickets/#{parent_ticket.display_id}/notes", nil, @write_headers
        assert_response 200
        parsed_response = JSON.parse(response.body)
        notes = parsed_response.select { |n| n['id'] = note.id }
        assert_equal 'Test update note body', notes[0]['body']
      end
    end
  end
end
