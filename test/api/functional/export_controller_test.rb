require_relative '../test_helper'
class ExportControllerTest < ActionController::TestCase

  def test_get_export_file_url_for_valid_params
    Account.current.launch :activity_export
    get :ticket_activities, controller_params(created_at: '2013-04-22')
    assert_response 200
    response = parse_response @response.body
    assert response["export"].is_a? Array
  end

  def test_get_export_file_url_for_nil_param
    Account.current.launch :activity_export
    get :ticket_activities, controller_params(created_at: nil)
    assert_response 200
    response = parse_response @response.body
    assert response["export"].is_a? Array
  end

  def test_get_export_file_url_for_invalid_params
    Account.current.launch :activity_export
    get :ticket_activities, controller_params(created_at: 'adsasd')
    assert_response 400
  end
end
