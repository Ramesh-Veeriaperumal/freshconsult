require_relative '../../../../test_helper'

class Channel::V2::Iam::AuthenticationControllerTest < ActionController::TestCase
  include Channel::V2::Iam::AuthenticationConstants
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

  def test_auth_by_channel_auth_header
    set_jwt_auth_header('sherlock')
    get :authenticate, controller_params(version: 'channel', url: '/api/channel/v2/billing')
    assert_equal JSON.parse(response.body)['success'], true
    assert response.headers.key?('x-fwi-client-token')
    key = OpenSSL::PKey::RSA.new(File.read('config/cert/iam_public.pem'))
    auth = response.headers['x-fwi-client-token'].match(/Bearer (.*)/)
    auth = auth[1].strip if !auth.nil? && auth.length > 1
    sub = (JWT.decode auth, key, true, algorithm: 'RS256').first['sub']
    assert_equal sub, 'sherlock'
    assert response.headers.key?('x-fwi-client-id')
    assert_equal response.headers['x-fwi-client-id'], 'sherlock'
    assert_response 200
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

  def test_basic_auth_for_put_method
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account)
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(agent.email, 'test')
    put :authenticate, controller_params(version: 'private')
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

  def test_iam_authenticate_token_for_valid_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 200, response.status
    assert JSON.parse(response.body)['access_token'].present?
    assert_equal 'Bearer', JSON.parse(response.body)['token_type']
    assert_equal Iam::IAM_CONFIG['expiry'], JSON.parse(response.body)['expires_in']
  end

  def test_iam_authenticate_token_for_request_with_missing_mandatory_field_client_id
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    # missing client_id
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:client_id, :missing_field)])
  end

  def test_iam_authenticate_token_for_request_with_missing_mandatory_field_grant_type
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    # missing grant_type
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:grant_type, :missing_field)])
  end

  def test_iam_authenticate_token_for_request_with_missing_mandatory_field_user_id
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    # missing user_id
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0])
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:user_id, :missing_field)])
  end

  def test_iam_authenticate_token_for_request_with_missing_mandatory_field_client_secret
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    # missing client_secret
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:client_secret, :missing_field)])
  end

  def test_iam_authenticate_token_for_invalid_grant_type_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: 'invalid_type',
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:grant_type, :invalid_field_values, attribute: :grant_type)])
  end

  def test_iam_authenticate_token_for_invalid_account_id_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    account_id: @current_account.id + 1,
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:account_id, :invalid_field_values, attribute: :account_id)])
  end

  def test_iam_authenticate_token_for_invalid_account_domain_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    account_domain: 'invalid_domain',
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:account_domain, :invalid_field_values, attribute: :account_domain)])
  end

  def test_iam_authenticate_token_for_invalid_client_id_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: 'invalid_client_id',
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:client_id, :invalid_field_values, attribute: :client_id)])
  end

  def test_iam_authenticate_token_when_request_content_type_is_not_form_urlencoded
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 415, response.status
    match_json(request_error_pattern(:invalid_content_type, content_type: 'application/json'))
  end

  def test_iam_authenticate_token_for_invalid_client_secret_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: 'invalid',
                                                    user_id: @current_account.users.last.id)
    assert_equal 401, response.status
    match_json(request_error_pattern(:invalid_credentials))
  end

  def test_iam_authenticate_token_for_invalid_scope_in_request
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id,
                                                    scope: 'manage_tickets, invalid_scope')
    assert_equal 400, response.status
    match_json([bad_request_error_pattern(:scope, :invalid_field_values, attribute: :scope)])
  end

  def test_iam_authenticate_token_when_user_does_not_have_the_privilege_in_request_scope
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: agent.id,
                                                    scope: 'manage_tickets, manage_forums')
    assert_equal 403, response.status
    match_json(request_error_pattern(:access_denied))
  end

  def test_iam_authenticate_token_for_valid_scope_for_user_then_jwt_constructed_with_only_specified_scope
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    agent = add_test_agent(@account, role: Role.where(name: 'Account Administrator').first.id)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: agent.id,
                                                    scope: 'manage_tickets')
    assert_equal 200, response.status
    assert JSON.parse(response.body)['access_token'].present?
    key = OpenSSL::PKey::RSA.new(File.read('config/cert/iam_public.pem'))
    token_privilege = (JWT.decode JSON.parse(response.body)['access_token'], key, true, algorithm: 'RS256').first['privileges']
    assert_equal true, !(token_privilege.to_i & 2**PRIVILEGES[:manage_tickets]).zero?
    assert_equal false, !(token_privilege.to_i & 2**PRIVILEGES[:manage_solutions]).zero?
  end

  def test_iam_authenticate_token_when_scope_not_specified_then_set_all_scope_of_user
    Channel::V2::Iam::AuthenticationController.any_instance.stubs(:private_api?).returns(false)
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    post :iam_authenticate_token, controller_params(version: 'channel',
                                                    grant_type: ALLOWED_GRANT_TYPES[0],
                                                    client_id: Iam::IAM_CLIENT_SECRETS.keys[0],
                                                    client_secret: Iam::IAM_CLIENT_SECRETS.values[0][0],
                                                    user_id: @current_account.users.last.id)
    assert_equal 200, response.status
    assert JSON.parse(response.body)['access_token'].present?
    key = OpenSSL::PKey::RSA.new(File.read('config/cert/iam_public.pem'))
    token_privilege = (JWT.decode JSON.parse(response.body)['access_token'], key, true, algorithm: 'RS256').first['privileges']
    assert_equal @current_account.users.last.privileges, token_privilege
  end
end
