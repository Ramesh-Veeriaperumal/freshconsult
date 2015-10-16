require_relative '../test_helper'
class ApiAgentsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_agent: params }
  end

  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  def test_agent_index
    get :index, controller_params
    assert_response 200
    agents = @account.all_agents
    pattern = agents.map { |agent| agent_pattern(agent) }
    match_json(pattern)
  end

  def test_agent_filter_state
    get :index, controller_params(state: 'fulltime')
    assert_response 200
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: false).count
    get :index, controller_params(state: 'occasional')
    assert_response 200
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: true).count
  end

  def test_agent_filter_email
    email = @account.all_agents.first.user.email
    get :index, controller_params(email: email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_with_invalid_email
    get :index, controller_params(email: '!@#$%')
    assert_response 400
    match_json([bad_request_error_pattern('email', 'Should be a valid email address')])
  end

  def test_agent_filter_mobile
    @account.all_agents.update_all(mobile: nil)
    @account.all_agents.first.user.update_column(:mobile, '1234567890')
    get :index, controller_params(mobile: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_phone
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567891')
    get :index, controller_params(phone: '1234567891')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_combined_filter
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567890')
    @account.all_agents.last.user.update_column(:phone, '1234567890')
    email = @account.all_agents.first.user.email
    get :index, controller_params(email: email, phone: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_index_with_invalid_filter
    get :index, controller_params(name: 'John')
    assert_response 400
    match_json([bad_request_error_pattern('name', 'invalid_field')])
  end

  def test_agent_filter_invalid_state
    get :index, controller_params(state: 'active')
    assert_response 400
    match_json([bad_request_error_pattern('state', 'not_included', list: 'occasional,fulltime')])
  end

  def test_show_agent
    sample_agent = @account.all_agents.first
    get :show, construct_params(id: sample_agent.user.id)
    assert_response 200
    match_json(agent_pattern(sample_agent))
  end

  def test_show_missing_agent
    get :show, construct_params(id: 60_000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_index_with_link_header
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    per_page = @account.all_agents.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/agents?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def agent_pattern(expected_output = {}, agent)
    user = {
      active: agent.user.active,
      created_at: agent.user.created_at,
      email: agent.user.email,
      job_title: agent.user.job_title,
      language: agent.user.language,
      last_login_at: agent.user.last_login_at,
      mobile: agent.user.mobile,
      name: agent.user.name,
      phone: agent.user.phone,
      time_zone: agent.user.time_zone,
      updated_at: agent.user.updated_at
    }

    {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: agent.created_at,
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature] || agent.signature,
      signature_html: expected_output[:signature_html] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: agent.updated_at,
      user: expected_output[:user] || user
    }
  end
end
