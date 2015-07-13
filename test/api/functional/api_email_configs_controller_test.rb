require_relative '../test_helper'
class ApiEmailConfigsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_email_config: params }
  end

  def test_index_email_configs
    get :index, request_params
    assert_equal EmailConfig.all, assigns(:items)
    assert_equal EmailConfig.all, assigns(:api_email_configs)
  end

  def test_show_email_config
    email_config = create_email_config
    get :show, construct_params(id: email_config.id)
    assert_response :success
    match_json(email_config_pattern(EmailConfig.find(email_config.id)))
  end

  def test_handle_show_request_for_missing_email_config
    get :show, construct_params(id: 2000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_email_config_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response :missing
    assert_equal ' ', response.body
  end
end
