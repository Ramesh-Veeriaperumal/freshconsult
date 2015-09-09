require_relative '../test_helper'

class NotesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::NotesHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 1,
        api_reply: 1,
        api_update: 4,
        api_destroy: 7,
        api_ticket_notes: 5,

        create: 60,
        reply: 63,
        update: 22,
        destroy: 20,
        ticket_notes: 16
      }

      ticket_id = Helpdesk::Ticket.first.display_id
      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/tickets/#{ticket_id}/notes", v2_note_payload, @write_headers)
        assert_response :created
      end
      v1[:create] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/conversations/note.json", v1_note_payload, @write_headers)
        assert_response :success
      end

      id1 = Helpdesk::Note.last(2).first.id
      id2 = Helpdesk::Note.last.id

      # notes
      v2[:ticket_notes], v2[:api_ticket_notes], v2[:ticket_notes_queries] = count_api_queries do
        get("/api/tickets/#{ticket_id}/notes", nil, @headers)
        assert_response :success
      end
      v1[:ticket_notes] = count_queries do
        get("/helpdesk/tickets/#{ticket_id}.json", nil, @headers)
        assert_response :success
      end
      # there is no notes method in v1

      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/notes/#{id1}", v2_note_update_payload, @write_headers)
        assert_response :success
      end
      # No public API to update a note in v1. Hence using a private one.
      v1[:update] = count_queries do
        put("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", v1_note_payload, @write_headers)
        assert_response :success
      end

      # delete
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/notes/#{id1}", nil, @headers)
        assert_response :no_content
      end
      # No public API to update a note in v1. Hence using a private one.
      v1[:destroy] = count_queries do
        delete("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", nil, @headers)
        assert_response :success
      end

      # reply
      v2[:reply], v2[:api_reply], v2[:reply_queries] = count_api_queries do
        post("/api/tickets/#{ticket_id}/reply", v2_reply_payload, @write_headers)
        assert_response :created
      end
      # No public API to reply to a ticket in v1. Hence using a private one.
      v1[:reply] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/conversations/reply.json", v1_reply_payload, @write_headers)
        assert_response :success
      end

      p v1
      p v2

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
