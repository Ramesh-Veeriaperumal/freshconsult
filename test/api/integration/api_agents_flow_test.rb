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
    turn_on_caching
    sample_agent = sample_user
    get "/api/v2/agents/#{sample_user.user.id}", nil,  @write_headers
    sample_agent.user.update_attributes(job_title: 'test update', language: 'en', mobile: '123123')
    get "/api/v2/agents/#{sample_user.user.id}", nil, @write_headers
    turn_off_caching
    assert_response 200
    match_json(agent_pattern({ job_title: 'test update', language: 'en', mobile: '123123' }, sample_agent.reload))
  end

  def test_caching_user_attributes_index
    turn_on_caching
    sample_agent = sample_user
    get '/api/v2/agents', nil, @write_headers
    sample_agent.user.update_attributes(job_title: 'test')
    get '/api/v2/agents', nil, @write_headers
    turn_off_caching
    assert_response 200
    parsed_response = JSON.parse(response.body)
    agents = parsed_response.select { |agent| agent['user']['id'] = sample_agent.user.id }
    assert_equal 1, agents.size
    assert_equal 'test', agents[0]['user']['job_title']
  end
end