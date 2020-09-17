require 'sidekiq/testing'
require 'webmock/minitest'
require_relative "../../../test_helper.rb"
Sidekiq::Testing.fake!

class Admin::AccountFeaturesControllerTest < ActionController::TestCase
  # include ApiAccountHelper

  def test_feature_enable_for_valid_input
    post :create, controller_params(name: 'cascade_dispatcher')
    assert_response 204
  end

  def test_feature_enable_for_invalid_input
    post :create, controller_params(name: 'invalid_feature')
    assert_response 400
  end

  def test_disable_setting_with_feature_dependency
    @account.launch(:feature_based_settings)
    @account.add_feature(:basic_settings_feature)
    delete :destroy, controller_params(name: 'cascade_dispatcher')
    assert_response 204
  ensure
    @account.rollback(:feature_based_settings)
  end

  def test_disable_setting_without_feature_dependency
    assert_raises(RuntimeError) do
      @account.launch(:feature_based_settings)
      @account.revoke_feature(:basic_settings_feature)
      delete :destroy, controller_params(name: 'cascade_dispatcher')
    end
  ensure
    @account.rollback(:feature_based_settings)
  end

  def test_disable_feature_for_valid_input
    delete :destroy, controller_params(name: 'cascade_dispatcher')
    assert_response 204
  end

  def test_disable_feature_for_invalid_input
    delete :destroy, controller_params(name: 'invalid_feature')
    assert_response 400
  end

  def test_feature_enable_for_help_widget
    post :create, controller_params(name: 'help_widget')
    assert_response 204
  end

   def test_disable_feature_for_help_widget
    delete :destroy, controller_params(name: 'help_widget')
    assert_response 204
  end
end
