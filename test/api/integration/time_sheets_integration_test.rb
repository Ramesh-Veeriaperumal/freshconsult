require_relative '../test_helper'

class TimeSheetsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::TimeSheetsHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 5,
        api_update: 5,
        api_index: 2,
        api_toggle_timer: 5,
        api_destroy: 5,
        api_ticket_time_sheets: 2,

        create: 21,
        update: 17,
        index: 13,
        toggle_timer: 19,
        destroy: 16,
        ticket_time_sheets: 14
      }

      ticket = create_ticket
      ticket_id = ticket.display_id
      api_v2_ticket = create_ticket
      api_v2_ticket_id = api_v2_ticket.display_id

      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/tickets/#{api_v2_ticket_id}/time_sheets", v2_time_sheet_payload, @write_headers)
        assert_response :created
      end
      v1[:create] = count_queries do
        post("/helpdesk/tickets/#{ticket_id}/time_sheets.json", v1_time_sheet_payload, @write_headers)
        assert_response :success
      end

      id1 = Helpdesk::TimeSheet.where(workable_id: api_v2_ticket_id).first.id
      id2 = Helpdesk::TimeSheet.where(workable_id: ticket.display_id).first.id

      # ticket_time_sheets
      v2[:ticket_time_sheets], v2[:api_ticket_time_sheets], v2[:ticket_time_sheets_queries] = count_api_queries do
        get("/api/tickets/#{ticket_id}/time_sheets", nil, @headers)
        assert_response :success
      end
      v1[:ticket_time_sheets] = count_queries do
        get("/helpdesk/tickets/#{ticket_id}/time_sheets.json", nil, @headers)
        assert_response :success
      end

      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/time_sheets/#{id1}", v2_time_sheet_update_payload, @write_headers)
        assert_response :success
      end
      v1[:update] = count_queries do
        put("/helpdesk/tickets/#{ticket_id}/time_sheets/#{id2}.json", v1_time_sheet_payload, @write_headers)
        assert_response :success
      end

      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/time_sheets', nil, @headers)
        assert_response :success
      end
      v1[:index] = count_queries do
        get('/helpdesk/time_sheets.json', nil, @headers)
        assert_response :success
      end

      # toggle_timer
      v2[:toggle_timer], v2[:api_toggle_timer], v2[:toggle_timer_queries] = count_api_queries do
        put("/api/time_sheets/#{id1}/toggle_timer",  {}.to_json, @write_headers)
        assert_response :success
      end
      v1[:toggle_timer] = count_queries do
        put("/helpdesk/time_sheets/#{id2}/toggle_timer.json", {}.to_json, @write_headers)
        assert_response :success
      end

      # destroy
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/time_sheets/#{id1}", nil, @headers)
        assert_response :no_content
      end
      v1[:destroy] = count_queries do
        delete("/helpdesk/tickets/#{ticket_id}/time_sheets/#{id2}.json", nil, @headers)
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
