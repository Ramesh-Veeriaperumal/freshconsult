require_relative '../../test_helper'

class ConversationsFlowTest < ActionDispatch::IntegrationTest
  include ConversationsTestHelper

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def test_caching_when_updating_note_body
    skip_bullet do
      parent_ticket = ticket
      note = create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)
      enable_cache do
        get "/api/v2/tickets/#{parent_ticket.display_id}/conversations", nil, @write_headers
        @account.make_current
        note.update_note_attributes(note_body_attributes: { body: 'Test update note body' })
        get "/api/v2/tickets/#{parent_ticket.display_id}/conversations", nil, @write_headers
        assert_response 200
        parsed_response = JSON.parse(response.body)
        conversations = parsed_response.detect { |n| n['id'] == note.id }
        assert_equal 'Test update note body', conversations['body_text']
      end
    end
  end
end
