require_relative '../test_helper'

class ApiAgentsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v1 = {}
    v2 = {}
    v2_expected = {
      show: 2,
      index: 2
    }

    id = Agent.first.user.id

    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/agents/#{id}", nil, @headers) }
    v1[:show] = count_queries { get("/agents/#{id}.json", nil, @headers) }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/agents', nil, @headers) }
    v1[:index] = count_queries { get('/agents.json', nil, @headers) }

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
    end

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
