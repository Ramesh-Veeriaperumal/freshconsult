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
end
