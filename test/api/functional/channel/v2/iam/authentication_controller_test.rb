require_relative '../../../../test_helper'

class Channel::V2::Iam::AuthenticationControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include ArchiveTicketTestHelper
  include RolesTestHelper

  def setup
    super
    @current_account = Account.first.make_current
    @controller.stubs(:api_current_user).returns(nil)
  end

  def tear_down
    Channel::V2::Iam::AuthenticationController.any_instance.unstub(:private_api?)
    @controller.unstub(:api_current_user)
  end

  def test_auth_by_freshid_api
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @current_account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, Time.now.to_i)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token)
    get :authenticate, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('Authorization')
    assert_response 200
  ensure
    @current_account.rollback(:api_jwt_auth)
  end

  def test_session_auth
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(true)
    privileges = ['manage_tickets', 'mange_contacts', 'view_contacts']
    role_without_manage_companies = create_role(name: Faker::Name.name,
                                                privilege_list: privileges)
    @agent = add_agent(@current_account, name: 'Agent without manage company privilege',
                                         role: role_without_manage_companies.id,
                                         role_ids: [role_without_manage_companies.id],
                                         privileges: role_without_manage_companies.privileges)
    create_session
    get :authenticate, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('Authorization')
    assert_response 200
  end

  def test_basic_auth
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(agent.email, 'test')
    get :authenticate, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('Authorization')
    assert_response 200
  end

  def test_basic_auth_for_post_method
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(agent.email, 'test')
    post :authenticate, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('Authorization')
    assert_response 200
  end

  def test_basic_auth_for_delete_method
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(agent.email, 'test')
    delete :authenticate, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('Authorization')
    assert_response 200
  end

  def test_auth_for_unauthorised_user
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    CustomRequestStore.store[:private_api_request] = false
    @current_account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, 2 * Time.now.to_i)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token)
    get :authenticate, controller_params(version: 'private')
    assert_equal 401, response.status
    match_json(request_error_pattern(:invalid_credentials))
  ensure
    CustomRequestStore.store[:private_api_request] = true
    @current_account.rollback(:api_jwt_auth)
  end
end
