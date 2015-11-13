require_relative '../test_helper'

class TimeEntriesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::TimeEntriesTestHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 7,
        api_update: 7,
        api_index: 2,
        api_toggle_timer: 7,
        api_destroy: 7,
        api_ticket_time_entries: 3,

        create: 22,
        update: 18,
        index: 14,
        toggle_timer: 20,
        destroy: 18,
        ticket_time_entries: 15
      }

      ticket = create_ticket
      ticket_id = ticket.display_id
      api_v2_ticket = create_ticket
      api_v2_ticket_id = api_v2_ticket.display_id

      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/tickets/#{api_v2_ticket_id}/time_entries", v2_time_entry_payload, @write_headers)
        assert_response 201
      end
      v1[:create] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/time_sheets.json", v1_time_entry_payload, @write_headers)
        assert_response 200
      end

      id1 = Helpdesk::TimeSheet.where(workable_id: api_v2_ticket_id).first.id
      id2 = Helpdesk::TimeSheet.where(workable_id: ticket.display_id).first.id

      # ticket_time_entries
      v2[:ticket_time_entries], v2[:api_ticket_time_entries], v2[:ticket_time_entries_queries] = count_api_queries do
        get("/api/tickets/#{ticket_id}/time_entries", nil, @headers)
        assert_response 200
      end
      v1[:ticket_time_entries] = count_queries do
        get("/helpdesk/tickets/#{ticket_id}/time_sheets.json", nil, @headers)
        assert_response 200
      end

      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/time_entries/#{id1}", v2_time_entry_update_payload, @write_headers)
        assert_response 200
      end
      v1[:update] = count_queries do
        put("/helpdesk/tickets/#{ticket_id}/time_sheets/#{id2}.json", v1_time_entry_payload, @write_headers)
        assert_response 200
      end

      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/time_entries', nil, @headers)
        assert_response 200
      end
      v1[:index] = count_queries do
        get('/helpdesk/time_sheets.json', nil, @headers)
        assert_response 200
      end

      # toggle_timer
      v2[:toggle_timer], v2[:api_toggle_timer], v2[:toggle_timer_queries] = count_api_queries do
        put("/api/time_entries/#{id1}/toggle_timer",  {}.to_json, @write_headers)
        assert_response 200
      end
      v1[:toggle_timer] = count_queries do
        put("/helpdesk/time_sheets/#{id2}/toggle_timer.json", {}.to_json, @write_headers)
        assert_response 200
      end

      # destroy
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/time_entries/#{id1}", nil, @headers)
        assert_response 204
      end
      v1[:destroy] = count_queries do
        delete("/helpdesk/tickets/#{ticket_id}/time_sheets/#{id2}.json", nil, @headers)
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
