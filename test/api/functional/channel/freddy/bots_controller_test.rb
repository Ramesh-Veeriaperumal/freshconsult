require_relative '../../../test_helper'
require 'webmock/minitest'
class Channel::Freddy::BotsControllerTest < ActionController::TestCase
  include FreddyHelper
  FREDDY = 'freddy'.freeze

  def setup
    super
    @account.reload
  end

  def wrap_cname(portal_id, widget_config)
    { bot: params(portal_id, widget_config) }
  end

  def test_create_bot
    enable_autofaq do
      set_jwt_auth_header(FREDDY)
      freshchat_account = Freshchat::Account.create(app_id: 'test', portal_widget_enabled: false, token: '', enabled: true)
      portal = create_portal
      widget_config = { 'headerProperty': { 'backgroundColor': '#02b874', 'backgroundImage': 'https://public-assets.staging.freddyproject.com/autofaq/2ea5b25a-01fb-4506-af8b-22074df7e951.png' } }
      post :create, controller_params({ version: 'private' }.merge(wrap_cname(portal.id, widget_config)), false)
      assert_response 200
    end
  ensure
    Account.current.freshchat_account.destroy
  end

  def test_destroy_bot
    enable_autofaq do
      set_jwt_auth_header(FREDDY)
      freshchat_account = Freshchat::Account.create(app_id: 'test', portal_widget_enabled: false, token: '', enabled: true)
      portal = create_portal
      widget_config = { 'headerProperty': { 'backgroundColor': '#02b874', 'backgroundImage': 'https://public-assets.staging.freddyproject.com/autofaq/2ea5b25a-01fb-4506-af8b-22074df7e951.png' } }
      freddy_bot = create_freddy(portal.id, widget_config)
      delete :destroy, controller_params({ version: 'private', id: freddy_bot.cortex_id }, false)
      assert_response 204
    end
  ensure
    Account.current.freshchat_account.destroy
  end

  def test_update_bot
    enable_autofaq do
      set_jwt_auth_header(FREDDY)
      freshchat_account = Freshchat::Account.create(app_id: 'test', portal_widget_enabled: false, token: '', enabled: true)
      portal = create_portal
      before_update_widget_config = { 'headerProperty': { 'backgroundColor': '#02b874', 'backgroundImage': 'https://public-assets.staging.freddyproject.com/autofaq/2ea5b25a-01fb-4506-af8b-22074df7e951.png' } }
      freddy_bot = create_freddy(portal.id, before_update_widget_config)
      after_update_widget_config = { 'headerProperty': { 'backgroundColor': '#02b875', 'backgroundImage': 'https://public-assets.staging.freddyproject.com/autofaq/2ea5b25a-01fb-4506-af8b-22074df7e950.png' } }
      put :update, controller_params({ version: 'private', id: freddy_bot.cortex_id }.merge(wrap_cname(portal.id, after_update_widget_config)), false)
      freddy_bot.reload
      assert_response 200
      assert_equal after_update_widget_config.to_s, freddy_bot.widget_config.to_s
    end
  ensure
    Account.current.freshchat_account.destroy
  end
end
