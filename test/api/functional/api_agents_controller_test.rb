require_relative '../test_helper'
class ApiAgentsControllerTest < ActionController::TestCase
  include AgentsTestHelper
  def wrap_cname(params)
    { api_agent: params }
  end

  def test_agent_index
    3.times do
      add_test_agent(@account, role: Role.find_by_name('Agent').id)
    end
    get :index, controller_params
    assert_response 200
    agents = @account.all_agents.order('users.name')
    pattern = agents.map { |agent| agent_pattern(agent) }
    match_json(pattern.ordered)
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
    match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
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
    match_json([bad_request_error_pattern('name', :invalid_field)])
  end

  def test_agent_filter_invalid_state
    get :index, controller_params(state: 'active')
    assert_response 400
    match_json([bad_request_error_pattern('state', :not_included, list: 'occasional,fulltime')])
  end

  def test_show_agent
    sample_agent = @account.all_agents.first
    get :show, construct_params(id: sample_agent.user.id)
    assert_response 200
    match_json(agent_pattern(sample_agent))
  end

  def test_show_agent_with_view_contact_privilege_only
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
    sample_agent = @account.all_agents.first
    get :show, construct_params(id: sample_agent.user.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
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

  def test_me
    get :me, controller_params
    assert_response 200
    match_json(agent_pattern(@account.all_agents.find(@agent.agent.id)))
  end

  # Agent email filter, passing an array to the email attribute

  def test_agent_filter_email_array
    email = sample_agent = @account.all_agents.first.user.email
    get :index, controller_params({ email: [email] }, false)
    assert_response 400
    match_json([bad_request_error_pattern('email', :data_type_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end
end
