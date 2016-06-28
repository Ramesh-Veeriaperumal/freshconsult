require_relative '../../test_helper'

class SurveysQueriesTest < ActionDispatch::IntegrationTest
  include SurveysTestHelper

  def test_query_count
    v2_keys = %w(create index ticket_surveys)

    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 12,
        api_index: 11,
        api_ticket_surveys: 13,

        create: 72,
        index: 11,
        ticket_surveys: 10
      }

      stub_custom_survey true
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/v2/tickets/#{ticket.display_id}/satisfaction_ratings", v2_survey_payload, @write_headers)
        assert_response 201
      end

      v2[:ticket_surveys], v2[:api_ticket_surveys], v2[:ticket_surveys_queries] = count_api_queries do
        get("/api/v2/tickets/#{ticket.display_id}/satisfaction_ratings", nil, @write_headers)
        assert_response 200
      end

      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/surveys/satisfaction_ratings', nil, @write_headers)
        assert_response 200
      end
      unstub_custom_survey

      write_to_file(v1, v2)

      v2_keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key},  v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end

      v1[:create] = count_queries do
        post("/helpdesk/tickets/#{ticket.display_id}/surveys/rate.json", v1_survey_payload, @write_headers)
        assert_response 200
      end

      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post("/api/v2/tickets/#{ticket.display_id}/satisfaction_ratings", v2_classic_survey_payload, @write_headers)
        assert_response 201
      end

      v1[:ticket_surveys] = count_queries do
        get("/helpdesk/tickets/#{ticket.display_id}/surveys.json", nil, @write_headers)
        assert_response 200
      end

      v2[:ticket_surveys], v2[:api_ticket_surveys], v2[:ticket_surveys_queries] = count_api_queries do
        get("/api/v2/tickets/#{ticket.display_id}/satisfaction_ratings", nil, @write_headers)
        assert_response 200
      end

      v1.keys.each do |key|
        assert v2[key] <= v1[key] + 9 # Extra Query in V2 due to Survey Remarks for showing note feedback which in V1 is nil always
      end
    end
  end
end
