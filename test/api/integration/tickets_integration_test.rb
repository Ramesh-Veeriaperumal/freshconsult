require_relative '../test_helper'

class TicketsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::TicketsHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 4,
        api_show: 3,
        api_update: 8,
        api_index: 6,
        api_destroy: 5,
        api_restore: 5,

        create: 113,
        show: 18,
        update: 60,
        index: 16,
        destroy: 32,
        restore: 32
      }

      # Assigning in prior so that query invoked as part of contruction of this payload will not be counted.
      create_v2_payload = v2_ticket_payload
      create_v1_payload = v1_ticket_payload

      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post('/api/tickets', create_v2_payload, @write_headers)
        assert_response :created
      end
      v1[:create] = count_queries do
        post('/helpdesk/tickets.json', create_v1_payload, @write_headers)
        assert_response :success
      end

      # 3 queries that will be part of new validations added to ticket validator for api. Hence substracting it.
      v2[:create] -= 3

      id1 = Helpdesk::Ticket.last(2).first.display_id
      id2 = Helpdesk::Ticket.last.display_id

      # show
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/tickets/#{id1}", nil, @headers)
        assert_response :success
      end
      v1[:show] = count_queries do
        get("/helpdesk/tickets/#{id2}.json", nil, @headers)
        assert_response :success
      end

      stub_current_account { create_note(user_id: @agent.id, ticket_id: id1, source: 2) }
      stub_current_account { create_note(user_id: @agent.id, ticket_id: id2, source: 2) }

      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/tickets/#{id1}", v2_ticket_update_payload, @write_headers)
        assert_response :success
      end
      v1[:update] = count_queries do
        put("/helpdesk/tickets/#{id2}.json", v1_update_ticket_payload, @write_headers)
        assert_response :success
      end
      # 12 queries that will be avoided while caching. Hence subtracting it.
      v2[:update] -= 12
      # 3 queries that will be part of new validations added to ticket validator for api. Hence substracting it.
      v2[:update] -= 3
      # 6 queries that will be avoided which caching in delegator. Hence subtracting it
      v2[:update] -= 6

      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/tickets', nil, @headers)
        assert_response :success
      end
      v1[:index] = count_queries do
        get('/helpdesk/tickets.json', nil, @headers)
        assert_response :success
      end

      # destroy
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/tickets/#{id1}", nil, @headers)
        assert_response :success
      end
      v1[:destroy] = count_queries do
        delete("/helpdesk/tickets/#{id2}.json", nil, @headers)
        assert_response :success
      end

      # restore
      v2[:restore], v2[:api_restore], v2[:restore_queries] = count_api_queries do
        put("/api/tickets/#{id1}/restore", {}.to_json, @write_headers)
        assert_response :success
      end
      v1[:restore] = count_queries do
        put("/helpdesk/tickets/#{id2}/restore.json", {}.to_json, @write_headers)
        assert_response :success
      end

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      end

      p v1
      p v2

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
