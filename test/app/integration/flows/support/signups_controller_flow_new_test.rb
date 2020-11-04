# frozen_string_literal: true

require_relative '../../../../../test/api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Support::SignupsControllerFlowNewTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_new_signup_when_logged_in
    @account.add_feature(:signup_link)
    user = add_new_user(@account, active: true)
    Support::SignupsControllerFlowNewTest.any_instance.stubs(:old_ui?).returns(true)
    set_request_auth_headers(user)
    get 'support/signup/new'
    assert_redirected_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
    Support::SignupsControllerFlowNewTest.any_instance.unstub(:old_ui?)
  end

  def test_new_signup_when_logged_out
    @account.add_feature(:signup_link)
    User.reset_current_user
    reset_request_headers
    get 'support/signup/new'
    assert_response 200
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
  end

  def test_create_signup_when_user_activation_email_notification_enabled
    @account.add_feature(:signup_link)
    User.reset_current_user
    @email_notification = @account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
    e_notif = @email_notification.requester_notification
    @email_notification.requester_notification = true
    @email_notification.save!
    params = { user: { name: 'Sample User', email: 'sampleuser@gmail.com' } }
    users_count_before = @account.users.count
    reset_request_headers
    post 'support/signup', params
    assert_equal I18n.t(:activation_link, email: params[:user][:email]), flash[:notice]
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
    @email_notification.requester_notification = e_notif
    @email_notification.save!
  end

  def test_create_signup_when_email_notification_is_false
    @account.add_feature(:signup_link)
    multi_language_enabled = @account.features?(:multi_language)
    @account.add_feature(:multi_language) unless multi_language_enabled
    User.reset_current_user
    reset_request_headers
    params = { user: { name: 'Sample User', email: 'sampleuser@gmail.com' } }
    post 'support/signup', params
    assert_equal I18n.t(:activation_link_no_email), flash[:notice]
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
    @account.revoke_feature(:multi_language) unless multi_language_enabled
  end

  def test_create_signup_without_session_maintainance
    @account.add_feature(:signup_link)
    User.reset_current_user
    User.any_instance.stubs(:save_without_session_maintenance).returns(false)
    params = { user: { name: 'Sample User', email: 'sampleuser@gmail.com' } }
    reset_request_headers
    post 'support/signup', params
    assert_template('new')
    assert_response 200
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
    User.any_instance.unstub(:save_without_session_maintenance)
  end

  def test_create_signup_for_restricted_helpdesk
    @account.add_feature(:signup_link)
    User.reset_current_user
    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    params = { user: { name: 'Sample User', email: '' } }
    reset_request_headers
    post 'support/signup', params
    assert_equal true, flash[:notice].include?(I18n.t('flash.login.signup_permission_denied'))
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:signup_link)
    Account.any_instance.unstub(:restricted_helpdesk?)
  end

  private

    def old_ui?
      false
    end
end
