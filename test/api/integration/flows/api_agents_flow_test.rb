require_relative '../../test_helper'

class ApiAgentsFlowTest < ActionDispatch::IntegrationTest
  include AgentsTestHelper

  def sample_user
    @account.all_agents.first
  end

  def request_params
    { id: sample_user.user.id }
  end

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

  def test_multipart_update_agent_with_all_params
    agent = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', level: 3, occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, group_ids: group_ids, job_title: Faker::Name.name }
    headers, params = encode_multipart(params)
    skip_bullet do
      put "/api/v2/agents/#{agent.id}", params, @headers.merge(headers)
    end
    assert_response 415
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
