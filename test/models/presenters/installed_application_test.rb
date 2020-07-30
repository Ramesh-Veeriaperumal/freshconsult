require_relative '../test_helper'
['installed_applications_test_helper.rb'].each { |file| require Rails.root.join("test/api/helpers/#{file}") }

class InstalledApplicationTest < ActiveSupport::TestCase
  include InstalledApplicationsTestHelper

  def test_installed_app_publish
    CentralPublisher::Worker.jobs.clear
    Marketplace::MarketPlaceObject.any_instance.stubs(:get_api).returns(nil)
    create_application('shopify')
    assert_equal 1, CentralPublisher::Worker.jobs.size
    assert_equal 'installed_application_create', CentralPublisher::Worker.jobs[0]['args'][0]
  end

  def test_central_publish_payload
    Marketplace::MarketPlaceObject.any_instance.stubs(:get_api).returns(nil)
    installed_app = Account.current.installed_applications.first || create_application('salesforce_v2')
    payload = installed_app.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_installed_app_pattern(installed_app))
  ensure
    Marketplace::MarketPlaceObject.any_instance.unstub(:get_api)
  end


end