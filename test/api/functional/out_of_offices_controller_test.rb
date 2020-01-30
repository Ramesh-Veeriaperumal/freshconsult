require_relative '../../test_helper.rb'

class OutOfOfficesControllerTest < ActionController::TestCase
  include OutOfOfficeTestHelper

  def wrap_cname(params)
    { out_of_office: params }
  end

  def test_list_all_out_of_offices
    toggle_out_of_office_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns(status: 200, data: sample_index)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_out_of_office_feature(false)
  end

  def test_show_out_of_office
    toggle_out_of_office_feature(true)
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns(status: 200, data: sample_show)
    get :index, controller_params
    assert_response 200
  ensure
    toggle_out_of_office_feature(false)
  end

  def toggle_out_of_office_feature(enable)
    enable ? Account.current.launch(:out_of_office) : Account.current.rollback(:out_of_office)
  end
end
