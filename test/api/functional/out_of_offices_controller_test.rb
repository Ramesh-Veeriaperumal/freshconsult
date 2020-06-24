require_relative '../../test_helper.rb'

class OutOfOfficesControllerTest < ActionController::TestCase
  include OutOfOfficeTestHelper

  def wrap_cname(params)
    { out_of_office: params }
  end

  def test_list_all_out_of_offices
    toggle_out_of_office_feature(true)
    req_stub = stub_request(:get, 'http://localhost:8080/api/v1/out-of-offices').to_return(body: sample_index.to_json, status: 200)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_out_of_office_feature(false)
    remove_request_stub(req_stub)
  end

  def test_show_out_of_office
    toggle_out_of_office_feature(true)
    req_stub = stub_request(:get, %r{^http://localhost:8080/api/v1/out-of-offices/.*?$}).to_return(body: sample_show.to_json, status: 200)
    get :show, controller_params(id: 1)
    assert_response 200
  ensure
    toggle_out_of_office_feature(false)
    remove_request_stub(req_stub)
  end

  def toggle_out_of_office_feature(enable)
    enable ? Account.current.launch(:out_of_office) : Account.current.rollback(:out_of_office)
  end
end
