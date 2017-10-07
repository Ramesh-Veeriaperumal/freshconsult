require_relative '../../test_helper'
class Ember::LivechatSettingControllerTest < ActionController::TestCase
  include LivechatSettingsTestHelper

  def setup
    #puts "ENTER setup livechat_setting_controller_test.rb"
    super
    chat_setting = Account.current.chat_setting
    chat_setting.enabled = true
    chat_setting.site_id = '4829eebbc8c611b6f0db5a0d64efeaac'
    chat_setting.active = true
    chat_setting.save
    chat_widget = Account.current.main_chat_widget
    chat_widget.widget_id = "0770d27e-7e87-4e47-a0f1-e722345d2f70"
    #chat_widget.chat_setting_id = chat_setting.id
    chat_widget.active = true
    chat_widget.save
    #puts "EXIT setup livechat_setting_controller_test.rb"
  end

  def test_index
    #puts "ENTER livechat_setting_controller"
    get :index, controller_params(version: 'private')
    assert_response 200
    #puts "EXIT just before match_json livechat_setting_controller: #{@response}"
    match_json(chat_settings_pattern)
  end

  def teardown
    super
    chat_setting = Account.current.chat_setting
    chat_setting.active = false
    chat_setting.save
    #chat_widget.chat_setting_id = chat_setting.id
    chat_widget = Account.current.main_chat_widget
    chat_widget.active = false
    chat_widget.save
  end

end
