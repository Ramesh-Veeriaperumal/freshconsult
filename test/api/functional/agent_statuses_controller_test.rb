require_relative '../../test_helper.rb'

class AgentStatusesControllerTest < ActionController::TestCase
  include AgentStatusTestHelper

  def wrap_cname(params)
    { agent_statuses: params }
  end

  def test_list_all_agent_statuses
    toggle_agent_status_feature(true)
    req_stub = stub_request(:get, 'http://localhost:8080/api/v1/agent-statuses').to_return(body: sample_show.to_json, status: 200)
    get :index, controller_params
    assert_response 200
  ensure
    remove_request_stub(req_stub)
    toggle_agent_status_feature(false)
  end

  def test_get_agent_statuses
    toggle_agent_status_feature(true)
    req_stub = stub_request(:get, %r{^http://localhost:8080/api/v1/agent-statuses/.*?$}).to_return(body: sample_show.to_json, status: 200)
    get :show, controller_params(id: 1)
    assert_response 200
  ensure
    remove_request_stub(req_stub)
    toggle_agent_status_feature(false)
  end

  def toggle_agent_status_feature(enable)
    enable ? Account.current.launch(:agent_statuses) : Account.current.rollback(:agent_statuses)
  end
end
