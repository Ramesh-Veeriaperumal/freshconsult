require_relative '../test_helper'

class ApiAgentsFlowTest < ActionDispatch::IntegrationTest
  include Helpers::AgentsTestHelper

  def sample_user
    @account.all_agents.first
  end

  def request_params
    { id: sample_user.user.id }
  end

  def test_caching_user_attributes_show
    enable_cache do
      sample_agent = sample_user
      get "/api/v2/agents/#{sample_user.user.id}", nil,  @write_headers
      sample_agent.user.update_attributes(job_title: 'test update', language: 'en', mobile: '123123')
      get "/api/v2/agents/#{sample_user.user.id}", nil, @write_headers
      assert_response 200
      match_json(agent_pattern({ job_title: 'test update', language: 'en', mobile: '123123' }, sample_agent.reload))
    end
  end

  def test_caching_user_attributes_index
    enable_cache do
      sample_agent = sample_user
      get '/api/v2/agents', nil, @write_headers
      sample_agent.user.update_attributes(job_title: 'test')
      get '/api/v2/agents', nil, @write_headers
      assert_response 200
      parsed_response = JSON.parse(response.body)
      agents = parsed_response.select { |agent| agent['contact']['email'] == sample_agent.user.email }
      assert_equal 1, agents.size
      assert_equal 'test', agents[0]['contact']['job_title']
    end
  end
end
