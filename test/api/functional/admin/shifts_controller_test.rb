require_relative '../../test_helper.rb'

class Admin::ShiftsControllerTest < ActionController::TestCase
  include ShiftTestHelper

  def wrap_cname(params)
    { shift: params }
  end

  def test_list_all_shifts
    toggle_agent_shifts_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: sample_index})
    get :index, controller_params
    assert_response 200
  ensure
    toggle_agent_shifts_feature(false)
  end

  def test_show_shift
    toggle_agent_shifts_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: sample_show})
    get :index, controller_params
    assert_response 200
  ensure
    toggle_agent_shifts_feature(false)
  end

  def toggle_agent_shifts_feature(enable)
    enable ? Account.current.launch(:agent_shifts) : Account.current.rollback(:agent_shifts)
  end
end
