require_relative '../../test_helper.rb'

class Admin::ShiftsControllerTest < ActionController::TestCase
  include ShiftTestHelper

  def wrap_cname(params)
    { shift: params }
  end

  def test_list_all_shifts
    toggle_agent_shifts_feature(true)
    req_stub = stub_request(:get, 'http://localhost:8080/api/v1/shifts/').to_return(body: sample_index.to_json, status: 200)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_agent_shifts_feature(false)
    remove_request_stub(req_stub)
  end

  def test_show_shift
    toggle_agent_shifts_feature(true)
    req_stub = stub_request(:get, %r{^http://localhost:8080/api/v1/shifts/.*?$}).to_return(body: sample_show.to_json, status: 200)
    get :show, controller_params(id: 1)
    assert_response 200
  ensure
    toggle_agent_shifts_feature(false)
    remove_request_stub(req_stub)
  end

  def toggle_agent_shifts_feature(enable)
    enable ? Account.current.launch(:agent_shifts) : Account.current.rollback(:agent_shifts)
  end
end
