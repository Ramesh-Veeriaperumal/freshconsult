require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'
require 'webmock/minitest'
class Reports::FreshvisualsControllerTest < ActionController::TestCase
  include Reports::Freshvisuals
  def setup
    super
    before_all
  end

  def teardown
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:freshreports_analytics_enabled?)
  end

  def before_all
    @account = Account.first.make_current
    @user = User.current || add_new_user(@account).make_current
    Account.any_instance.stubs(:freshreports_analytics_enabled?).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_analytics).returns(true)
  end

  def test_download_schedule_file_without_privilege
    User.any_instance.stubs(:privilege?).with(:view_analytics).returns(false)
    get :download_schedule_file, controller_params(uuid: 'freshvisuals')
    assert_response 200
    match_json(access_denied: true)
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_download_schedule_file_without_analytics_feature
    Account.any_instance.stubs(:freshreports_analytics_enabled?).returns(false)
    get :download_schedule_file, controller_params(uuid: 'freshvisuals')
    assert_response 200
    match_json(access_denied: true)
  ensure
    Account.any_instance.unstub(:freshreports_analytics_enabled?)
  end

  def test_download_schedule_file_success
    stub_request(:get, 'http://dummy/app/export/freshvisuals').to_return(status: 200, body: success_response.to_json, headers: { 'Content-Type' => 'application/json' })
    get :download_schedule_file, controller_params(uuid: 'freshvisuals')
    assert_response 200
    match_json(export: { url: 'export_url' })
  end

  def test_download_schedule_file_failure
    stub_request(:get, 'http://dummy/app/export/freshvisuals').to_return(status: 400, body: failure_response.to_json, headers: { 'Content-Type' => 'application/json' })
    get :download_schedule_file, controller_params(uuid: 'freshvisuals')
    assert_response 200
    match_json(message: 'Request Failed. Please schedule your export / contact support@freshdesk.com for more assistance.')
  end

  def test_download_schedule_file_with_exception
    stub_request(:get, 'http://dummy/app/export/freshvisuals').to_raise(StandardError)
    get :download_schedule_file, controller_params(uuid: 'freshvisuals')
    assert_response 200
    match_json(message: 'Please contact support@freshdesk.com for more assistance.')
  end

  private

    def success_response
      {
        response: 'export_url'
      }
    end

    def failure_response
      {
        message: 'Request Failed'
      }
    end
end
