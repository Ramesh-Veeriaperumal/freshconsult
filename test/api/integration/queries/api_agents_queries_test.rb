require_relative '../../test_helper'

class ApiAgentsQueriesTest < ActionDispatch::IntegrationTest
  include AgentsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.features.gamification_enable.create
    @@before_all_run = true
  end

  def test_query_count
    v1 = {}
    v2 = {}
    v2_expected = {
      api_show: 3,
      api_index: 3,
      api_me: 3,
      api_update: 15,
      api_destroy: 2,

      show: 11,
      index: 11,
      me: 11,
      update: 62,
      destroy: 58
    }

    id1 = Agent.where('user_id != ?', @agent.id).last.try(:user_id) || add_test_agent(@account, role: Role.find_by_name('Agent').id).id

    id2 = Agent.where('user_id  NOT IN ( ? )', [@agent.id, id1]).last.try(:id) || add_test_agent(@account, role: Role.find_by_name('Agent').id).agent.id

    # update
    v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
      put("/api/v2/agents/#{id1}", v2_agent_payload, @write_headers)
      assert_response 200
    end
    v1[:update] = count_queries do
      put("/agents/#{id2}.json", v1_agent_payload, @write_headers)
      assert_response 200
    end

    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/agents/#{id1}", nil, @headers)
      assert_response 200
    end
    v1[:show] = count_queries do
      get("/agents/#{id2}.json", nil, @headers)
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

    # api/v2/agents/me is introduced in V2 and we can compare this with V1's show to
    # me
    v2[:me], v2[:api_me], v2[:me_queries] = count_api_queries do
      get('/api/v2/agents/me', nil, @headers)
      assert_response 200
    end
    v1[:me] = count_queries do
      get("/agents/#{id2}.json", nil, @headers)
      assert_response 200
    end

    # destroy
    v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
      delete("/api/v2/agents/#{id1}", nil, @headers)
      assert_response 204
    end
    v1[:destroy] = count_queries do
      put("/agents/#{id2}/convert_to_contact.json", nil, @headers)
      assert_response 302
    end

    v2[:me] -= 1
    v1[:me] += 1 # account suspended check is done in v2 alone.

    write_to_file(v1, v2)

    Rails.logger.error "V1: #{v1.inspect}, V2: #{v2.inspect}, V2_Expected: #{v2_expected.inspect}"

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
