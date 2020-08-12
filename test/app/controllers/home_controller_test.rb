require_relative '../../api/test_helper'
require_relative '../../core/helpers/controller_test_helper'
require_relative '../../core/helpers/account_test_helper'

class HomeControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include Redis::Keys::Others
  include Redis::OthersRedis

  def setup
    @account = Account.first.presence || create_test_account
    @user = Account.current.technicians.first.make_current
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

  def test_csp_policy_header_if_no_feature
    html_content = '<html><body>Hey buddy.. test works!!</body></html>'
    Net::HTTP.stubs(:get).with(URI(AppConfig['falcon_ui']['index_page'])).returns(html_content)
    get :index_html
    assert_response 200
    assert_equal response.headers['Content-Security-Policy-Report-Only'], nil
  end

  def test_csp_policy_header_if_redis_key_exist
    Account.current.launch(:csp_reports)
    csp = "default-src 'self'; script-src https://*.cloudfront.net cdn.headwayapp.co *.freshcloud.io https://assets.freshpo.com https://cdn.heapanalytics.com; style-src https://wchat.freshchat.com; img-src https://*.cloudfront.net https://heapanalytics.com; connect-src https://*.freshworksapi.com https://*.freshpo.com; report-uri /api/_/cspreports"
    set_others_redis_key(CONTENT_SECURITY_POLICY_AGENT_PORTAL, csp, 60)
    html_content = '<html><body>Hey buddy.. test works!!</body></html>'
    Net::HTTP.stubs(:get).with(URI(AppConfig['falcon_ui']['index_page'])).returns(html_content)
    get :index_html
    assert_response 200
    assert_equal response.headers['Content-Security-Policy-Report-Only'], csp
  end

  def test_csp_policy_header_if_redis_key_not_set
    # test code
    Account.current.launch(:csp_reports)
    staging_csp = "default-src 'self'; script-src https://*.cloudfront.net cdn.headwayapp.co *.freshcloud.io https://assets.freshpo.com https://cdn.heapanalytics.com; style-src https://wchat.freshchat.com; img-src https://*.cloudfront.net https://heapanalytics.com; connect-src https://*.freshworksapi.com https://*.freshpo.com; report-uri /api/_/cspreports"
    set_others_redis_key(CONTENT_SECURITY_POLICY_AGENT_PORTAL, '', 60)
    html_content = '<html><body>Hey buddy.. test works!!</body></html>'
    Net::HTTP.stubs(:get).with(URI(AppConfig['falcon_ui']['index_page'])).returns(html_content)
    get :index_html
    assert_response 200
    assert_equal response.headers['Content-Security-Policy-Report-Only'], staging_csp
  end
end
