require_relative '../../test_helper'
class Ember::MarketplaceAppsControllerTest < ActionController::TestCase
  include MarketplaceTestHelper

  def test_index
    Ember::MarketplaceAppsController.any_instance.stubs(:installed_extensions).returns(installed_extensions_v2)
    Ember::MarketplaceAppsController.any_instance.stubs(:extension_details_v2).returns(extension_details_v2)
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(marketplace_apps_pattern)
  end

  def test_index_when_marketplace_down
    Ember::MarketplaceAppsController.any_instance.stubs(:installed_extensions).returns(Exception)
    get :index, controller_params(version: 'private')
    assert_response 503
    match_json(request_error_pattern(:marketplace_service_unavailable))
  end

  def test_index_agent_oauth
    Ember::MarketplaceAppsController.any_instance.stubs(:installed_extensions).returns(installed_extensions_v2)
    Ember::MarketplaceAppsController.any_instance.stubs(:extension_details_v2).returns(extension_details_v2_agent_oauth)
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(marketplace_apps_agent_oauth)
  end
end
