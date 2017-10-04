require_relative '../../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class Ember::Admin::OnboardingControllerTest < ActionController::TestCase
  include AccountTestHelper
  include UsersTestHelper
  include OnboardingTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @user = create_test_account
  end

  def channels_params
    @channels ||= %w[phone forums social]
  end

  def test_channel_update_with_valid_channels
    @account.set_account_onboarding_pending
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 204
    assert_channel_selection(channels_params)
  end

  def test_channel_update_with_invalid_channels
    channels_params << 'emai'
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 400
  end

  def test_channel_update_after_onboarding_complete
    Account.current.complete_account_onboarding
    post :update_channel_config, construct_params(version: 'private', channels: channels_params)
    assert_response 404
    Account.current.set_account_onboarding_pending
  end

  def test_update_activation_email_with_valid_email
    new_email = Faker::Internet.email
    put :update_activation_email, construct_params(version: 'private', new_email: new_email)
    assert_response 204
    assert_equal @user.account.admin_email, new_email
  end

  def test_update_activation_email_with_invalid_email
    put :update_activation_email, construct_params(version: 'private', new_email: Faker::Lorem.word)
    assert_response 400
  end

  def test_update_activation_email_with_empty_email
    put :update_activation_email, construct_params(version: 'private', new_email: '')
    assert_response 400
  end

  def test_update_activation_email_with_no_email_field
    put :update_activation_email, construct_params(version: 'private')
    assert_response 400
  end

  def test_resend_activation_email
    get :resend_activation_email, construct_params(version: 'private')
    assert_response 204
  end
end
