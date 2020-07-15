require_relative '../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Integrations::MarketplaceAppsControllerTest < ActionController::TestCase
  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current || create_test_account
    @account.add_feature(:marketplace)
  end

  def teardown
    @account.revoke_feature(:marketplace)
    super
  end

  def create_application(type)
    Integrations::Application.create(build_application_hash(type))
  end

  def build_application_hash(type)
    options_hash = {
      old_app: {
        keys_order: [:application_id],
        application_id: {
          type: :text,
          required: true,
          label: 'integrations.test_app.form.application_id'
        }
      },
      auth_form: {
        keys_order: [:application_id],
        application_id: {
          type: :text,
          required: true,
          label: 'integrations.test_app.form.application_id'
        }
      },
      auth_form_direct: {
        direct_install: true,
        auth_url: '/account/test_app/auth'
      },
      oauth_direct: {
        direct_install: true,
        oauth_url: '/account/test_app/oauth'
      },
      user_specific_auth: {
        direct_install: true,
        user_specific_auth: true
      }
    }

    {
      name: 'test_app',
      display_name: 'test_app',
      description: 'test_app',
      listing_order: 51,
      application_type: 'test_app',
      options: options_hash[type]
    }
  end

  def test_install_for_old_integration
    @application = create_application(:old_app)
    @application.save!
    Account.stubs(:current).returns(@account)
    post :install, controller_params(id: @application[:name])
    assert_response 302
  ensure
    Account.unstub(:current)
    @application.destroy
  end

  def test_install_for_new_gallery
    @application = create_application(:auth_form)
    @application.save!
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    post :install, controller_params(id: @application[:name])
    assert_response 200
    assert_equal(JSON.parse(response.body)['action'], 'auth_form_install')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    @application.destroy
  end

  def test_install_for_new_gallery_oauth_install
    @application = create_application(:oauth_direct)
    @application.save!
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    post :install, controller_params(id: @application[:name])
    assert_response 200
    assert_equal(JSON.parse(response.body)['action'], 'oauth_redirect_install')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    @application.destroy
  end

  def test_install_for_new_gallery_form_install
    @application = create_application(:auth_form_direct)
    @application.save!
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    post :install, controller_params(id: @application[:name])
    assert_response 200
    assert_equal(JSON.parse(response.body)['action'], 'auth_form_install')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    @application.destroy
  end

  def test_install_for_new_gallery_direct_install
    @application = create_application(:user_specific_auth)
    @application.save!
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    post :install, controller_params(id: @application[:name])
    assert_response 200
    assert_equal(JSON.parse(response.body)['action'], 'direct_app_install')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    Integrations::InstalledApplication.any_instance.unstub(:save!)
    @application.destroy
  end

  def test_cleanup_cache_and_etags
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    DataVersioning::ExternalModel.stubs(:update_version_timestamp).returns(nil)
    MemcacheKeys.stubs(:delete_from_cache).returns(true)
    post :clear_cache
    assert_response 202
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    DataVersioning::ExternalModel.unstub(:update_version_timestamp)
    MemcacheKeys.unstub(:delete_from_cache)
  end

  def test_app_status_success
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    mock = OpenStruct.new(status: 200, body: { "status" => "SUCCESS" })
    FreshRequest::Client.any_instance.stubs(:get).returns(mock)
    get :app_status, controller_params(id: 'salesforce_v2', installed_extension_id: 165_123)
    assert_response 200
    assert_equal JSON.parse(response.body)['status'], 'SUCCESS'
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    FreshRequest::Client.any_instance.unstub(:get)
  end

  def test_app_status_failed
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    mock = OpenStruct.new(status: 200, body: { 'status' => "FAILED" })
    FreshRequest::Client.any_instance.stubs(:get).returns(mock)
    get :app_status, controller_params(id: 'salesforce_v2', installed_extension_id: 165_123)
    assert_response 200
    assert_equal JSON.parse(response.body)['status'], 'FAILED'
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    FreshRequest::Client.any_instance.unstub(:get)
  end

  def test_app_status_inprogress
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    mock = OpenStruct.new(status: 202, body: {})
    FreshRequest::Client.any_instance.stubs(:get).returns(mock)
    get :app_status, controller_params(id: 'salesforce_v2', installed_extension_id: 165_123)
    assert_response 404
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    FreshRequest::Client.any_instance.unstub(:get)
  end

  def test_app_status_inprogress_failed
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    mock = OpenStruct.new(status: 500, body: {})
    FreshRequest::Client.any_instance.stubs(:get).returns(mock)
    get :app_status, controller_params(id: 'salesforce_v2', installed_extension_id: 165_123)
    assert_response 404
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    FreshRequest::Client.any_instance.unstub(:get)
  end
end
