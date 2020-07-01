require_relative '../../test_helper'
class Ember::ConfigsControllerTest < ActionController::TestCase
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

  def test_config_response
    User.any_instance.stubs(:time_zone).returns('Casablanca')
    User.any_instance.stubs(:language).returns('en')
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:firstName], @user.name
    assert_equal payload[:email], @user.email
    assert_equal payload[:userId], @user.id
    assert_equal payload[:timezone], 'Africa/Casablanca'
    assert_equal payload[:language], 'en'
    assert_equal payload[:portalUrl], "#{@account.url_protocol}://#{@account.full_domain}"
    assert_equal payload[:page], 'home'
    assert_equal payload[:exp], payload[:iat] + FreshVisualsConfig['early_expiration'].to_i
  ensure
    User.any_instance.unstub(:time_zone)
    User.any_instance.unstub(:language)
  end
  
  def test_omni_freshvisuals_config_response
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.any_instance.stubs(:omni_reports_enabled?).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns('178040553247198293')
    Account.any_instance.stubs(:organisation).returns(Organisation.new)
    Organisation.any_instance.stubs(:organisation_id).returns('178040553184283730')
    freshid_user = Freshid::V2::Models::User.new(id: '178040553263975511', email: @user.email)
    Freshid::V2::Models::User.stubs(:find_by_email).with(@user.email).returns(freshid_user)
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:email], @user.email
    assert_equal payload[:userId], @user.id
    assert_equal payload[:uuid], '178040553263975511'
    assert_equal payload[:orgId], '178040553184283730'
    assert_equal payload[:bundleId], '178040553247198293'
    assert_equal payload[:exp], payload[:iat] + OmniFreshVisualsConfig['early_expiration'].to_i
    assert_equal payload[:sessionExpiration], Time.now.to_i + OmniFreshVisualsConfig['session_expiration'].to_i
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.any_instance.unstub(:omni_reports_enabled?)
    Account.any_instance.unstub(:omni_bundle_id)
    Account.any_instance.unstub(:organisation)
    Organisation.any_instance.unstub(:organisation_id)
    Freshid::V2::Models::User.unstub(:find_by_email)
  end

  def test_config_response_with_null_user_language
    User.any_instance.stubs(:language).returns(nil)
    Account.any_instance.stubs(:language).returns('ar')
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:language], 'ar'
  ensure
    User.any_instance.unstub(:language)
    Account.any_instance.unstub(:language)
  end

  def test_invalid_config_response
    get :show, controller_params(version: 'private', id: 'abc')
    assert_response 400
    match_json([bad_request_error_pattern('id', :not_included, list: 'freshvisuals,freshsales')])
  end

  def test_config_response_with_feature_disabled
    Account.any_instance.stubs(:freshreports_analytics_enabled?).returns(false)
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Freshreports Analytics'))
  end

  def test_config_response_without_privilege
    User.any_instance.stubs(:privilege?).with(:view_analytics).returns(false)
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_fetch_config_with_freshsales
    Ember::ConfigsController.any_instance.stubs(:current_account).returns(Account.first)
    Account.any_instance.stubs(:organisation).returns(Organisation.new)
    Account.any_instance.stubs(:organisation_accounts).returns(dummy_freshid_org_accounts_response_with_freshsales)
    Organisation.any_instance.stubs(:domain).returns('arjunpn.freshworks.com')
    get :show, controller_params(version: 'private', id: 'freshsales')
    assert_response 200
    payload = JSON.parse(response.body)
    assert_equal payload['url'], 'test.freshsales.io'
  ensure
    Ember::ConfigsController.any_instance.unstub(:current_account)
    Account.any_instance.unstub(:organisation)
    Account.any_instance.unstub(:organisation_accounts)
    Organisation.any_instance.unstub(:domain)
  end

  def test_fetch_config_without_freshsales
    Ember::ConfigsController.any_instance.stubs(:current_account).returns(Account.first)
    Account.any_instance.stubs(:organisation).returns(Organisation.new)
    Account.any_instance.stubs(:organisation_accounts).returns(dummy_freshid_org_accounts_response_without_freshsales)
    Organisation.any_instance.stubs(:domain).returns('arjunpn.freshworks.com')
    get :show, controller_params(version: 'private', id: 'freshsales')
    assert_response 200
    payload = JSON.parse(response.body)
    assert_nil payload['url']
  ensure
    Ember::ConfigsController.any_instance.unstub(:current_account)
    Account.any_instance.unstub(:organisation)
    Account.any_instance.unstub(:organisation_accounts)
    Organisation.any_instance.unstub(:domain)
  end

  def test_invalid_freshsales_config
    Ember::ConfigsController.any_instance.stubs(:current_account).returns(Account.first)
    Account.any_instance.stubs(:organisation_accounts).returns(nil)
    Account.any_instance.stubs(:organisation_from_cache).returns(Organisation.new)
    Organisation.any_instance.stubs(:alternate_domain).returns('arjunpn.freshworks.com')
    get :show, controller_params(version: 'private', id: 'freshsales')
    assert_response 404
  ensure
    Ember::ConfigsController.any_instance.unstub(:current_account)
    Account.any_instance.unstub(:organisation_accounts)
    Account.any_instance.unstub(:organisation_from_cache)
    Organisation.any_instance.unstub(:alternate_domain)
  end

  def dummy_freshid_org_accounts_response_with_freshsales
    {
      'accounts': [
        {
          'id': '1',
          'organisation_id': 'test001',
          'product_id': '41441393816600581',
          'domain': 'test.freshdesk.com'
        },
        {
          'id': '2',
          'organisation_id': 'test001',
          'product_id': '66069886861266193',
          'domain': 'test.freshsales.io'
        }
      ],
      'total_size': '100',
      'page_number': 0,
      'page_size': 0,
      'has_more': true
    }
  end

  def dummy_freshid_org_accounts_response_without_freshsales
    {
      'accounts': [
        {
          'id': '1',
          'organisation_id': 'test001',
          'product_id': '41441393816600581',
          'domain': 'test.freshdesk.com'
        },
        {
          'id': '2',
          'organisation_id': 'test001',
          'product_id': '119321760701761820',
          'domain': 'test.freshmarketer.io'
        }
      ],
      'total_size': '100',
      'page_number': 0,
      'page_size': 0,
      'has_more': true
    }
  end
end
