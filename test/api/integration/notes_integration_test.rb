require_relative '../test_helper'

class NotesIntegrationTest < ActionDispatch::IntegrationTest
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
      v2[:create], v2[:api_create] = count_api_queries { post("/api/tickets/#{ticket_id}/notes", v2_note_payload, @write_headers) }
      v1[:create] = count_queries { post("/helpdesk/tickets/#{ticket_id}/conversations/note.json", v1_note_payload, @write_headers) }

      id1 = Helpdesk::Note.last(2).first.id
      id2 = Helpdesk::Note.last.id

      # notes
      v2[:ticket_notes], v2[:api_ticket_notes] = count_api_queries { get("/api/tickets/#{ticket_id}/notes", nil, @headers) }
      v1[:ticket_notes] = count_queries { get("/helpdesk/tickets/#{ticket_id}.json", nil, @headers) }
      # there is no notes method in v1

      # update
      v2[:update], v2[:api_update] = count_api_queries { put("/api/notes/#{id1}", v2_note_update_payload, @write_headers) }
      # No public API to update a note in v1. Hence using a private one.
      v1[:update] = count_queries { put("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", v1_note_payload, @write_headers) }

      # delete
      v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/notes/#{id1}", nil, @headers) }
      # No public API to update a note in v1. Hence using a private one.
      v1[:destroy] = count_queries { delete("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", nil, @headers) }

      # reply
      v2[:reply], v2[:api_reply] = count_api_queries { post("/api/tickets/#{ticket_id}/reply", v2_reply_payload, @write_headers) }
      # No public API to reply to a ticket in v1. Hence using a private one.
      v1[:reply] = count_queries { post("/helpdesk/tickets/#{ticket_id}/conversations/reply.json", v1_reply_payload, @write_headers) }

      p v1
      p v2

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      end

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
