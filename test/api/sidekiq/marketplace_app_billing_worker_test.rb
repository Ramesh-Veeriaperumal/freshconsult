require_relative '../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!
class Integrations::MarketplaceAppBillingWorkerTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first || create_new_account
    Account.stubs(:current).returns(@account)
    Account.current.stubs(:features).returns(@account)
    Account.any_instance.stubs(:features?).with(:marketplace).returns(true)
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    application = Integrations::Application.where(name: 'dynamics_v2').first
    @installed_app = @account.installed_applications.build(application: application)
    @installed_app.set_configs(title: 'dynamics crm', domain: 'ensembleworld.connect.io', password: 'notsafeanymore')
    @installed_app.save!
  end

  def teardown
    @installed_app.destroy if @installed_app.present?
    Account.unstub(:current)
    Account.any_instance.unstub(:features?)
    Account.any_instance.unstub(:marketplace_gallery_enabled?)
    super
  end

  def test_marketplace_app_billing_inprogress
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    args = HashWithIndifferentAccess.new(app_name: 'dynamics_v2')
    ni_details = HashWithIndifferentAccess.new('addon_id' => 'dummycache', 'install_type' => nil)
    inprogress_response = OpenStruct.new(status: 202)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:marketplace_ni_extension_details).returns(ni_details)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:fetch_app_status).returns(inprogress_response)
    assert_raises StandardError do
      Integrations::MarketplaceAppBillingWorker.new.perform(args)
    end
  ensure
    Integrations::MarketplaceAppBillingWorker.unstub(:marketplace_ni_extension_details)
    Integrations::MarketplaceAppBillingWorker.unstub(:fetch_app_status)
  end

  def test_marketplace_app_billing_failed
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    args = HashWithIndifferentAccess.new(app_name: 'dynamics_v2')
    ni_details = HashWithIndifferentAccess.new('addon_id' => 'dummycache', 'install_type' => nil)
    failed_data = {
      status: 200,
      body: {
        'status' => 'FAILED'
      }
    }
    failed_response = OpenStruct.new(failed_data)
    ::MarketplaceAppHelper.stubs(:marketplace_ni_extension_details).returns(ni_details)
    ::Marketplace::ApiMethods.stubs(:fetch_app_status).returns(failed_response)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:marketplace_ni_extension_details).returns(ni_details)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:fetch_app_status).returns(failed_response)
    Integrations::MarketplaceAppBillingWorker.new.perform(args)
    assert_equal @account.installed_applications.with_name(args['app_name']).count, 0
  ensure
    Integrations::MarketplaceAppBillingWorker.unstub(:marketplace_ni_extension_details)
    Integrations::MarketplaceAppBillingWorker.unstub(:fetch_app_status)
  end

  def test_marketplace_app_billing_success
    Account.any_instance.stubs(:marketplace_gallery_enabled?).returns(true)
    args = HashWithIndifferentAccess.new(app_name: 'dynamics_v2')
    ni_details = HashWithIndifferentAccess.new('addon_id' => 'dummycache', 'install_type' => nil)
    sucess_data = {
      status: 200,
      body: {
        'status' => 'SUCCESS'
      }
    }
    sucess_response = OpenStruct.new(sucess_data)
    ::MarketplaceAppHelper.stubs(:marketplace_ni_extension_details).returns(ni_details)
    ::Marketplace::ApiMethods.stubs(:fetch_app_status).returns(sucess_response)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:marketplace_ni_extension_details).returns(ni_details)
    Integrations::MarketplaceAppBillingWorker.any_instance.stubs(:fetch_app_status).returns(sucess_response)
    Integrations::MarketplaceAppBillingWorker.new.perform(args)
    assert_equal @account.installed_applications.with_name(args['app_name']).count, 1
  ensure
    Integrations::MarketplaceAppBillingWorker.unstub(:marketplace_ni_extension_details)
    Integrations::MarketplaceAppBillingWorker.unstub(:fetch_app_status)
  end
end
