require_relative '../test_helper'

class ApiAgentsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v1 = {}
    v2 = {}
    v2_expected = {
      api_show: 2,
      api_index: 2,

      show: 12,
      index: 12
    }

    id = Agent.first.user.id

    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/agents/#{id}", nil, @headers)
      assert_response 200
    end
    v1[:show] = count_queries do
      get("/agents/#{id}.json", nil, @headers)
      assert_response 200
    end

    v2[:show] -= 1
    v1[:show] += 1 # account suspended check is done in v2 alone.

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/agents', nil, @headers)
      assert_response 200
    end
    v1[:index] = count_queries do
      get('/agents.json', nil, @headers)
      assert_response 200
    end

    v2[:index] -= 1

    write_to_file(v1, v2)

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
