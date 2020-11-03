# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'webmock/minitest'
class PasswordResetsFlowNewTest < ActionDispatch::IntegrationTest
  include UsersHelper
  include AccountTestHelper

  def setup
    super
  end

  def teardown
    super
  end

  def test_password_resets_for_logged_in_user
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    PasswordResetsFlowNewTest.any_instance.stubs(:old_ui?).returns(true)
    set_request_auth_headers(user)
    post '/password_resets', params
    assert_equal I18n.t(:'flash.general.login_not_needed'), flash[:notice]
    assert_redirected_to root_url
  ensure
    @account.make_current
    PasswordResetsFlowNewTest.any_instance.unstub(:old_ui?)
    user.destroy
  end

  # logged out users' cases
  def test_password_resets_for_logged_out_reset_not_allowed_user
    user = add_new_user(@account, active: false)
    params = { email: user.email }
    User.any_instance.stubs(:allow_password_reset?).returns(false)
    User.reset_current_user
    post '/password_resets', params
    assert I18n.t(:'flash.password_resets.email.not_allowed'), flash[:notice]
    assert_redirected_to login_path
  ensure
    @account.make_current
    User.any_instance.unstub(:allow_password_reset?)
    user.destroy
  end

  def test_password_resets_for_logged_out_user
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    delayed_jobs_count_before = Delayed::Job.count
    User.reset_current_user
    post '/password_resets', params
    assert_equal delayed_jobs_count_before + 1, Delayed::Job.count
    assert I18n.t(:'flash.password_resets.email.success'), flash[:notice]
    assert_redirected_to root_url
  ensure
    @account.make_current
    user.destroy
  end

  def test_password_resets_create_for_freshid_agent
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:freshid_agent?).returns(true)
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    @account.launch(:freshid)
    post '/password_resets', params
    assert_response 302
  ensure
    @account.make_current
    @account.rollback(:freshid)
    PasswordResetsController.any_instance.unstub(:freshid_agent?)
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_create_for_freshid_agent_with_orgv2_feature
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:freshid_agent?).returns(true)
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    @account.launch(:freshid_org_v2)
    post '/password_resets', params
    assert_response 302
  ensure
    @account.make_current
    @account.rollback(:freshid_org_v2)
    PasswordResetsController.any_instance.unstub(:freshid_agent?)
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_create_for_freshid_agent_using_mobile
    WebMock.allow_net_connect!
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    delayed_jobs_count_before = Delayed::Job.count
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:freshid_agent?).returns(true)
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(true)
    req_stub = stub_request(:post, 'http://freshid.local.dev/oauth/token?grant_type=client_credentials').to_return(status: 200, body: { access_token: 'sampleToken', expires_in: 300 }.to_json, headers: {})
    post '/password_resets', params
    message = I18n.t(:'flash.password_resets.email.success')
    expected_params = { server_response: message, reset_password: 'success' }
    assert_equal delayed_jobs_count_before, Delayed::Job.count
    assert expected_params, response.body
  ensure
    remove_request_stub(req_stub)
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    PasswordResetsController.any_instance.unstub(:freshid_agent?)
    user.destroy
    WebMock.disable_net_connect!
  end

  def test_password_resets_create_for_freshid_agent_using_mobile_with_orgv2_feature
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    delayed_jobs_count_before = Delayed::Job.count
    @account.launch(:freshid_org_v2)
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:freshid_agent?).returns(true)
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(true)
    post '/password_resets', params
    message = I18n.t(:'flash.password_resets.email.success')
    expected_params = { server_response: message, reset_password: 'success' }
    assert_equal delayed_jobs_count_before, Delayed::Job.count
    assert expected_params, response.body
  ensure
    @account.make_current
    @account.rollback(:freshid_org_v2)
    PasswordResetsController.any_instance.unstub(:freshid_agent?)
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_not_a_logged_in_mobile_users
    user = add_new_user(@account, active: true)
    params = { email: user.email }
    delayed_jobs_count_before = Delayed::Job.count
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(true)
    post '/password_resets', params
    message = I18n.t(:'flash.password_resets.email.success')
    expected_params = { server_response: message, reset_password: 'success' }
    assert_equal delayed_jobs_count_before + 1, Delayed::Job.count
    assert expected_params, response.body
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_for_not_a_user_using_mobile
    user = add_new_user(@account, active: true)
    email = user.email
    user.destroy
    params = { email: email }
    delayed_jobs_count_before = Delayed::Job.count
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(true)
    post '/password_resets', params
    assert_equal delayed_jobs_count_before, Delayed::Job.count
    message = I18n.t(:'flash.password_resets.email.success')
    expected_params = { server_response: message, reset_password: 'failure' }
    assert expected_params, response.body
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
  end

  def test_password_resets_for_not_a_user
    user = add_new_user(@account, active: true)
    email = user.email
    user.destroy
    params = { email: email }
    delayed_jobs_count_before = Delayed::Job.count
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    post '/password_resets', params
    assert_equal delayed_jobs_count_before, Delayed::Job.count
    assert I18n.t(:'flash.password_resets.email.success'), flash[:notice]
    assert_redirected_to root_url
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
  end

  def test_password_resets_new_action
    User.reset_current_user
    get '/password_resets/new'
    assert_redirected_to support_login_path(anchor: 'forgot_password')
  end

  def test_password_resets_edit_action_for_user
    user = add_new_user(@account, active: true)
    id = user.perishable_token
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    get "/password_resets/#{id}/edit"
    assert_template('layouts/activations')
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_for_edit_action_for_agent
    user = add_agent(@account, active: true)
    id = user.perishable_token
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    get "/password_resets/#{id}/edit"
    assert_template('layouts/activations')
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_edit_action_for_invalid_user
    user = add_agent(@account, active: true)
    id = user.perishable_token
    user.destroy
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    get "/password_resets/#{id}/edit"
    assert_equal I18n.t(:'flash.password_resets.update.invalid_token'), flash[:notice]
    assert_redirected_to root_url
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
  end

  def test_password_resets_edit_for_user_with_reset_not_allowed
    user = add_agent(@account, active: true)
    id = user.perishable_token
    User.any_instance.stubs(:allow_password_reset?).returns(false)
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    get "/password_resets/#{id}/edit"
    assert_equal I18n.t(:'flash.password_resets.email.not_allowed'), flash[:notice]
    assert_redirected_to login_path
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    User.any_instance.unstub(:allow_password_reset?)
    user.destroy
  end

  def test_password_resets_for_edit_action_for_freshid_agent
    user = add_agent(@account, active: true)
    id = user.perishable_token
    PasswordResetsController.any_instance.stubs(:freshid_agent?).returns(true)
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    get "/password_resets/#{id}/edit"
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
    assert_redirected_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:freshid_agent?)
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_for_update_action_success
    user = add_new_user(@account, active: true)
    id = user.perishable_token
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    params = { user: { password: 'Testtest', password_confirmation: 'Testtest' } }
    put "/password_resets/#{id}", params
    user.reload
    assert_not_equal id, user.perishable_token
    assert_equal I18n.t(:'flash.password_resets.update.success'), flash[:notice]
    assert_redirected_to root_url
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end

  def test_password_resets_for_update_action_failure
    user = add_new_user(@account, active: true)
    id = user.perishable_token
    User.reset_current_user
    PasswordResetsController.any_instance.stubs(:is_native_mobile?).returns(false)
    params = { user: { password: 'Testtest', password_confirmation: 'Mismatchpassword' } }
    put "/password_resets/#{id}", params
    assert_equal id, user.perishable_token
    assert_template('layouts/activations')
  ensure
    @account.make_current
    PasswordResetsController.any_instance.unstub(:is_native_mobile?)
    user.destroy
  end
end
