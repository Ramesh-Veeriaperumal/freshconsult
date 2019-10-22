require_relative '../../test_helper'
class Ember::OmniChannelsControllerTest < ActionController::TestCase
  include OmniChannelsTestHelper

  def test_index
    channel_availability
    @account.reload
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(channel_json({facebook: true, twitter: true, freshcaller: true, freshchat: true }))
  end

  def test_index_without_channels
    Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
    no_channels
    @account.reload
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(channel_json({}))
  ensure
    Social::FacebookPage.any_instance.unstub(:gateway_facebook_page_mapping_details)
  end

end
