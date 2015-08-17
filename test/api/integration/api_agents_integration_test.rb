require_relative '../test_helper'

class ApiAgentsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v2_expected = {
      show: 2,
      index: 2
    }

    id = Agent.first.user.id

    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/agents/#{id}", nil, @headers) }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/agents', nil, @headers) }

    v2.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert_equal v2_expected[key], v2[api_key]
    end

  end
end
