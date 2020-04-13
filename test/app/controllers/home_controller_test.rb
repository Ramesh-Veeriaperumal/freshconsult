require_relative '../../api/test_helper'
require_relative '../../core/helpers/controller_test_helper'

class HomeControllerTest < ActionController::TestCase
  include ControllerTestHelper
  def setup
    super
  end

  def test_mobile_app_onboarding_calls_for_android
    login_admin
    @request.env['HTTP_USER_AGENT'] = 'Android'
    @request['HTTP_COOKIE'] = { 'skip_mobile_app_download' => false }

    get :index
    assert_response 302
  end

  def test_mobile_app_onboarding_calls_for_ios
    login_admin
    @request.env['HTTP_USER_AGENT'] = 'ios'
    @request['HTTP_COOKIE'] = { 'skip_mobile_app_download' => false }

    get :index
    assert_response 302
  end

  def test_mobile_app_onboarding_calls_for_desktop
    login_admin
    @request.env['HTTP_USER_AGENT'] = 'Chrome/75.0.3770.142'
    @request['HTTP_COOKIE'] = { 'skip_mobile_app_download' => false }

    get :index
    assert_response 302
  end

  def test_index_html_to_return_index_page
    html_content = '<html><body>Hey buddy.. test works!!</body></html>'
    Net::HTTP.stubs(:get).with(URI(AppConfig['falcon_ui']['index_page'])).returns(html_content)
    get :index_html
    assert_response 200
    assert_equal response.body, html_content
  ensure
    Net::HTTP.unstub(:get)
  end
end
