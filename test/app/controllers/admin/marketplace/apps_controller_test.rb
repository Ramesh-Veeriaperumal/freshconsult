require_relative '../../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Admin::Marketplace::AppsControllerTest < ActionController::TestCase
  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
  end

  def test_gallery_wo_feature
    Account.stubs(:current).returns(@account)
    get :index
    assert_response 302
    assert_includes(response.body, 'redirected')
  ensure
    Account.unstub(:current)
  end

  def test_gallery_with_feature
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    get :index
    assert_response 200
    assert_includes(JSON.parse(response.body)['url'], 'params')
    assert_includes(JSON.parse(response.body)['url'], 'doorkeeper')
    assert_includes(JSON.parse(response.body)['url'], 'freshID=false')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
  end

  def test_gallery_with_freshid_v2
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    Account.any_instance.stubs(:organisation_domain).returns('testdomain')
    Account.any_instance.stubs(:organisation_id).returns('12345')
    get :index
    assert_response 200
    assert_includes(JSON.parse(response.body)['url'], 'params')
    assert_includes(JSON.parse(response.body)['url'], @account.domain)
    refute_includes(JSON.parse(response.body)['url'], 'freshID')
    refute_includes(JSON.parse(response.body)['url'], 'doorkeeper')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:organisation_domain)
    Account.any_instance.unstub(:organisation_id)
  end

  def test_gallery_with_freshid_integration
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    get :index
    assert_response 200
    assert_includes(JSON.parse(response.body)['url'], 'params')
    assert_includes(JSON.parse(response.body)['url'], @account.domain)
    refute_includes(JSON.parse(response.body)['url'], 'freshID')
    refute_includes(JSON.parse(response.body)['url'], 'doorkeeper')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
  end
end
