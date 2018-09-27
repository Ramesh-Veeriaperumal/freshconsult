require_relative '../../test_helper'

class Ember::IntegratedUsersControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper

  def setup
    super
    # mkt_place = Account.current.features?(:marketplace)
    # Account.current.features.marketplace.destroy if mkt_place
    # Account.current.reload
    Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
  end

  def teardown
    super
    Integrations::InstalledApplication.unstub(:marketplace_enabled?)
  end

  def wrap_cname(params)
    { integrated_users: params }
  end

  def test_index
    agent = add_test_agent(@account)
    app = Integrations::Application.find_by_name('harvest')
    harvest_app = Account.current.installed_applications.find_by_application_id(app.id)
    harvest_app = create_application('harvest') if harvest_app.nil?
    user_params = {
      app_name: 'harvest',
      user_id: agent.id,
      remote_user_id: 2,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    get :index, controller_params({ version: 'private', installed_application_id: harvest_app.id, user_id: agent.id }, true)
    assert_response 200
    integ_users = harvest_app.user_credentials.first
    assert_equal(user_params[:user_id], integ_users[:user_id])
  end

  def test_show_integ_user
    resource = Integrations::UserCredential.first
    get :show, construct_params(version: 'private', id: resource.id)
    assert_response 200
  end

  def test_index_with_no_installed_id
    agent = add_test_agent(@account)
    harvest_app = Integrations::Application.find_by_name('harvest')
    user_params = {
      app_name: 'harvest',
      user_id: agent.id,
      remote_user_id: 3,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    get :index, controller_params({ version: 'private', user_id: agent.id }, true)
    match_json([bad_request_error_pattern('installed_application_id', :installed_application_id_required, code: :missing_field)])
    assert_response 400
  end

  def test_index_with_no_user_id
    agent = add_test_agent(@account)
    harvest_app = Integrations::Application.find_by_name('harvest')
    user_params = {
      app_name: 'harvest',
      user_id: agent.id,
      remote_user_id: 4,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    get :index, controller_params({ version: 'private', installed_application_id: harvest_app.id }, true)
    match_json([bad_request_error_pattern('user_id', :user_id_required, code: :missing_field)])
    assert_response 400
  end

  def test_index_empty_response
    agent = add_test_agent(@account)
    harvest_app = Integrations::Application.find_by_name('harvest')
    user_params = {
      app_name: 'harvest',
      user_id: agent.id + 5,
      remote_user_id: 5,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    get :index, controller_params({ version: 'private', installed_application_id: harvest_app.id, user_id: agent.id }, true)
    assert_response 200
    assert_equal '[]', response.body
  end

  def test_user_credentials_add
    agent = add_test_agent(@account)
    harvest_app = Integrations::InstalledApplication.find_by_application_id(Integrations::Application.find_by_name('harvest').id)
    post :user_credentials_add, controller_params({ version: 'private', username: 'ttt', password: Base64.encode64('fff'), installed_application_id: harvest_app.id }, true)
    assert_response 204
  end

  def test_user_credentials_add_without_installed_app_id
    agent = add_test_agent(@account)
    harvest_app = Integrations::InstalledApplication.find_by_application_id(Integrations::Application.find_by_name('harvest').id)
    post :user_credentials_add, controller_params({ version: 'private', username: 'ttt', password: Base64.encode64('fff') }, true)
    match_json([bad_request_error_pattern('installed_application_id', :installed_application_id_required, code: :missing_field)])
    assert_response 400
  end

  def test_user_credentials_add_without_username
    agent = add_test_agent(@account)
    harvest_app = Integrations::InstalledApplication.find_by_application_id(Integrations::Application.find_by_name('harvest').id)
    post :user_credentials_add, controller_params({ version: 'private', password: Base64.encode64('fff'), installed_application_id: harvest_app.id }, true)
    match_json([bad_request_error_pattern('username', :username_required, code: :missing_field)])
    assert_response 400
  end

  def test_user_credentials_add_without_password
    agent = add_test_agent(@account)
    harvest_app = Integrations::InstalledApplication.find_by_application_id(Integrations::Application.find_by_name('harvest').id)
    post :user_credentials_add, controller_params({ version: 'private', username: 'ttt', installed_application_id: harvest_app.id }, true)
    match_json([bad_request_error_pattern('password', :password_required, code: :missing_field)])
    assert_response 400
  end

  def test_user_credentials_remove
    agent = add_test_agent(@account)
    agent.make_current
    login_as(agent)
    user_params = {
      app_name: 'harvest',
      user_id: agent.id,
      remote_user_id: 6,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    delete :user_credentials_remove, controller_params({ version: 'private', 
      installed_application_id: integ_user.installed_application_id }, true)
    login_as(get_admin)
    assert_response 204
  end

  def test_user_credentials_remove_without_installed_app_id
    agent = add_test_agent(@account)
    user_params = {
      app_name: 'harvest',
      user_id: agent.id,
      remote_user_id: 7,
      auth_info: {
        username: 'freshdesk.3@gmail.com',
        password: 'RnJlc2hkZXNrQDEyMw=='
      }
    }
    integ_user = create_integ_user_credentials(user_params)
    harvest_app = Integrations::InstalledApplication.find_by_application_id(Integrations::Application.find_by_name('harvest').id)
    delete :user_credentials_remove, controller_params({ version: 'private' }, true)
    match_json([bad_request_error_pattern('installed_application_id', :installed_application_id_required, code: :missing_field)])
    assert_response 400
  end

  def test_user_credentials_with_invalid_installed_app_id
    delete :user_credentials_remove, controller_params({ version: 'private', installed_application_id: 1234 }, true)
    match_json([bad_request_error_pattern('installed_application_id', :"is invalid")])
    assert_response 400
  end
end
