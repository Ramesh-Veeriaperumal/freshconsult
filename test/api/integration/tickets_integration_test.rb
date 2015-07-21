require_relative '../test_helper'

class TicketsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        create: 1,
        show: 2,
        update: 3,
        index: 7,
        destroy: 5,
        restore: 5,
        assign: 8,
        notes: 5
      }

      # create
      v2[:create], v2[:api_create] = count_api_queries { post('/api/tickets', v2_ticket_payload, @write_headers) }
      v1[:create] = count_queries { post('/helpdesk/tickets.json', v1_ticket_payload, @write_headers) }

      id1 = Helpdesk::Ticket.last(2).first.display_id
      id2 = Helpdesk::Ticket.last.display_id

      # show
      v2[:show], v2[:api_show] = count_api_queries { get("/api/tickets/#{id1}", nil, @headers) }
      v1[:show] = count_queries { get("/helpdesk/tickets/#{id2}.json", nil, @headers) }

      create_note(user_id: @agent.id, ticket_id: id1, source: 2)
      create_note(user_id: @agent.id, ticket_id: id2, source: 2)
      # notes
      v2[:notes], v2[:api_notes] = count_api_queries { get("/api/tickets/#{id1}/notes", nil, @headers) }
      v1[:notes] = count_queries { get("/helpdesk/tickets/#{id2}.json", nil, @headers) }
      # there is no notes method in v1

      # update
      v2[:update], v2[:api_update] = count_api_queries { put("/api/tickets/#{id1}", v2_ticket_update_payload, @write_headers) }
      v1[:update] = count_queries { put("/helpdesk/tickets/#{id2}.json", v1_update_ticket_payload, @write_headers) }
      # 12 queries that will be avoided while caching. Hence subtracting it.
      v2[:update] -= 12

      # assign
      v2[:assign], v2[:api_assign] = count_api_queries { put("/api/tickets/#{id1}/assign", { user_id: @agent.id }.to_json, @write_headers) }
      v1[:assign] = count_queries { put("/helpdesk/tickets/#{id2}/assign.json", { 'responder_id' => @agent.id }.to_json, @write_headers) }

      # index
      v2[:index], v2[:api_index] = count_api_queries { get('/api/tickets', nil, @headers) }
      v1[:index] = count_queries { get('/helpdesk/tickets.json', nil, @headers) }

      # destroy
      v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/tickets/#{id1}", nil, @headers) }
      v1[:destroy] = count_queries { delete("/helpdesk/tickets/#{id2}.json", nil, @headers) }

      # restore
      v2[:restore], v2[:api_restore] = count_api_queries { put("/api/tickets/#{id1}/restore", {}.to_json, @write_headers) }
      v1[:restore] = count_queries { put("/helpdesk/tickets/#{id2}/restore.json", {}.to_json, @write_headers) }

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
        assert v2[key] <= v1[key]
        assert_equal v2_expected[key], v2[api_key]
      end
    end
  end
end
