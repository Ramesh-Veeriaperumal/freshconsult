require_relative '../../test_helper'

class ConversationsQueriesTest < ActionDispatch::IntegrationTest
  include ConversationsTestHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 2,
        api_reply: 2,
        api_update: 6,
        api_destroy: 9,
        api_conversations: 5,

        create: 57,
        reply: 55,
        update: 23,
        destroy: 21,
        conversations: 16
      }

      ticket_id = Helpdesk::Ticket.first.display_id
      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/tickets/#{ticket_id}/notes", v2_note_payload, @write_headers)
        assert_response 201
      end
      v1[:create] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/conversations/note.json", v1_note_payload, @write_headers)
        assert_response 200
      end

      id1 = Helpdesk::Note.last(2).first.id
      id2 = Helpdesk::Note.last.id

      # conversations
      v2[:conversations], v2[:api_conversations], v2[:conversations_queries] = count_api_queries do
        get("/api/tickets/#{ticket_id}/conversations", nil, @headers)
        assert_response 200
      end
      v1[:conversations] = count_queries do
        get("/helpdesk/tickets/#{ticket_id}.json", nil, @headers)
        assert_response 200
      end
      # there is no notes method in v1

      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/conversations/#{id1}", v2_note_update_payload, @write_headers)
        assert_response 200
      end
      # No public API to update a note in v1. Hence using a private one.
      v1[:update] = count_queries do
        put("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", v1_note_payload, @write_headers)
        assert_response 200
      end

      # delete
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/conversations/#{id1}", nil, @headers)
        assert_response 204
      end
      # No public API to update a note in v1. Hence using a private one.
      v1[:destroy] = count_queries do
        delete("/helpdesk/tickets/#{ticket_id}/notes/#{id2}.json", nil, @headers)
        assert_response 200
      end

      # reply
      v2[:reply], v2[:api_reply], v2[:reply_queries] = count_api_queries do
        post("/api/tickets/#{ticket_id}/reply", v2_reply_payload, @write_headers)
        assert_response 201
      end
      # No public API to reply to a ticket in v1. Hence using a private one.
      v1[:reply] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/conversations/reply.json", v1_reply_payload, @write_headers)
        assert_response 200
      end

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
