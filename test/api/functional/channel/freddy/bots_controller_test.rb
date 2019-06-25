require_relative '../../../test_helper'
require 'webmock/minitest'
class Channel::Freddy::BotsControllerTest < ActionController::TestCase
  include FreddyHelper
  FREDDY = 'freddy'.freeze

  def setup
    super
  end

  def wrap_cname(portal_id)
    { bot: params(portal_id) }
  end

  def test_create_bot_without_bot_feature
    set_jwt_auth_header(FREDDY)
    post :create, controller_params({ version: 'private' }.merge(wrap_cname(Portal.first.id)), false)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Autofaq'))
  end

  def test_create_bot_without_access
    enable_autofaq do
      post :create, controller_params({ version: 'private' }.merge(wrap_cname(Portal.first.id)), false)
      assert_response 401
      match_json(request_error_pattern(:invalid_credentials))
    end
  end

  def test_create_bot
    enable_autofaq do
      set_jwt_auth_header(FREDDY)
      stub_request(:post, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, status: 200)
      post :create, controller_params({ version: 'private' }.merge(wrap_cname(Portal.first.id)), false)
      assert_response 200
    end
  end

  def test_update_bot
    enable_autofaq do
      set_jwt_auth_header(FREDDY)
      portal = create_portal
      stub_request(:post, %r{^#{Freshchat::Account::CONFIG[:signup][:host]}.*?$}).to_return(body: freshchat_response, status: 200)
      freddy_bot = create_freddy(portal.id)
      put :update, controller_params({ version: 'private', id: freddy_bot.cortex_id }.merge(wrap_cname(portal.id)), false)
      assert_response 200
    end
  end
end
