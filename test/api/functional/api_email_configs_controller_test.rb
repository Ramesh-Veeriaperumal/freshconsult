require_relative '../test_helper'
class ApiEmailConfigsControllerTest < ActionController::TestCase
  include Helpers::EmailConfigsHelper

  def wrap_cname(params)
    { api_email_config: params }
  end

  def test_index
    get :index, request_params
    pattern = []
    Account.current.all_email_configs.all.each do |ec|
      pattern << email_config_pattern(ec.id)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_email_config
    email_config = create_email_config
    get :show, construct_params(id: email_config.id)
    assert_response 200
    match_json(email_config_pattern(EmailConfig.find(email_config.id)))
  end

  def test_handle_show_request_for_missing_email_config
    get :show, construct_params(id: 2000)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_email_config_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_index_without_privilege
    email_config = create_email_config
    User.any_instance.stubs(:privilege?).returns(false).once
    get :show, construct_params(id: email_config.id)
    assert_response 403
    match_json(request_error_pattern('access_denied'))
  end

  def test_index_with_link_header
    3.times do
      create_email_config
    end
    per_page =   Account.current.all_email_configs.all.count - 1
    get :index, construct_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/email_configs?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, construct_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
