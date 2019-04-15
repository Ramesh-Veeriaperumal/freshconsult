require 'sidekiq/testing'
require 'webmock/minitest'
require_relative "../../../test_helper.rb"
Sidekiq::Testing.fake!

class Admin::Account::FeaturesControllerTest < ActionController::TestCase
  # include ApiAccountHelper

  def test_feature_enable_for_valid_input
    post :create, controller_params(name: 'cascade_dispatcher')
    assert_response 204
  end

  def test_feature_enable_for_invalid_input
    post :create, controller_params(name: 'invalid_feature')
    assert_response 400
  end

  def test_disable_feature_for_valid_input
    delete :destroy, controller_params(name: 'cascade_dispatcher')
    assert_response 204
  end

  def test_disable_feature_for_invalid_input
    delete :destroy, controller_params(name: 'invalid_feature')
    assert_response 400
  end
end
