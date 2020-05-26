require_relative '../../test_helper.rb'

class AgentStatusesControllerTest < ActionController::TestCase
  include AgentStatusTestHelper

  def wrap_cname(params)
    { agent_statuses: params }
  end

  def test_list_all_agent_statuses
    toggle_agent_status_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns(status: 200, data: sample_index)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_agent_status_feature(false)
  end

  def test_get_agent_statuses
    toggle_agent_status_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns(status: 200, data: sample_show)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_agent_status_feature(false)
  end

  def toggle_agent_status_feature(enable)
    enable ? Account.current.launch(:agent_statuses) : Account.current.rollback(:agent_statuses)
  end
end
