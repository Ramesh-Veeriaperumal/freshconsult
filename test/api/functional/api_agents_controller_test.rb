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
    assert_response :success
    agents = @account.all_agents
    pattern = agents.map { |agent| agent_pattern(agent) }
    match_json(pattern)
  end

  def test_agent_filter_state
    get :index, controller_params({state: 'fulltime'})
    assert_response :success
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: false).count
    get :index, controller_params({state: 'occasional'})
    assert_response :success
    response = parse_response @response.body
    assert response.size == Agent.where(occasional: true).count
  end

  def test_agent_filter_email
    email = @account.all_agents.first.user.email
    get :index, controller_params({email: email})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_mobile
    @account.all_agents.update_all(mobile: nil)
    @account.all_agents.first.user.update_column(:mobile, '1234567890')
    get :index, controller_params({mobile: '1234567890'})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end
  
  def test_agent_filter_phone
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567891')
    get :index, controller_params({phone: '1234567891'})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_filter_combined_filter
    @account.all_agents.update_all(phone: nil)
    @account.all_agents.first.user.update_column(:phone, '1234567890')
    @account.all_agents.last.user.update_column(:phone, '1234567890')
    email = @account.all_agents.first.user.email
    get :index, controller_params({email: email, phone: '1234567890'})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_agent_index_with_invalid_filter
    get :index, controller_params({name: 'John'})
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "invalid_field")])
  end

  def test_show_agent
    sample_agent = @account.all_agents.first
    get :show, construct_params({id: sample_agent.user.id})
    assert_response :success
    match_json(agent_pattern(sample_agent))
  end

  def test_show_missing_agent
    get :show, construct_params({id: 60000})
    assert_response :missing
    assert_equal ' ', response.body
  end
end