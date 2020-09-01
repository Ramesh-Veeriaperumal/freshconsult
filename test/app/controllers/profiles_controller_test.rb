require_relative '../../test_helper'
require_relative '../../api/test_helper'
require_relative '../../core/helpers/users_test_helper'
require_relative '../../core/helpers/controller_test_helper'

class ProfilesControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include CoreUsersTestHelper

  def setup
    super
  end

  def test_edit
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    get :edit, id: user.id
    assert_response 200
    log_out
    user.destroy
  end

  def test_update_success
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    put :update, user: { language: 'fr' }, id: user.id
    user.reload
    assert_response 200
    assert_equal user.language, 'fr'
    log_out
    user.destroy
  end

  def test_update_failure
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    Agent.any_instance.stubs(:update_attributes).returns(false)
    put :update, id: user.id
    assert_response 422
    log_out
    user.destroy
  end

  def test_reset_api_key
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    initial_api_key = user.single_access_token
    put :reset_api_key
    user.reload
    new_api_key = user.single_access_token
    assert_response 302
    assert_not_equal initial_api_key, new_api_key
    log_out
    user.destroy
  end

  def test_change_password_success
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    user.password = 'test12345'
    user.save!
    old_crypted_password = user.crypted_password
    old_password = 'test12345'
    new_password = 'test1234'
    post :change_password, user: { current_password: old_password, password: new_password, password_confirmation: new_password }, id: user.id
    user.reload
    assert_response 200
    assert_not_equal old_crypted_password, user.crypted_password
    log_out
    user.destroy
  end

  def test_change_password_failure
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    user.password = 'test12345'
    user.save!
    old_password = 'test12345'

    new_password = ''
    post :change_password, user: { current_password: old_password, password: new_password, password_confirmation: new_password }, id: user.id
    assert_response 200
    assert_equal old_password, user.password

    new_password = 'test1234'
    password_confirmation = 'test123456'
    post :change_password, user: { current_password: old_password, password: new_password, password_confirmation: password_confirmation }, id: user.id
    assert_response 200
    assert_equal old_password, user.password

    log_out
    user.destroy
  end

  def test_notification_read
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    put :notification_read
    assert_response 200
    timestamp = user.agent.notification_timestamp
    assert_equal timestamp.day, Time.new.utc.day
  end

  def test_onboarding_complete
    user = add_agent(Account.current, active: true)
    user.make_current
    login_as(user)
    put :on_boarding_complete
    assert_response 200
    assert_equal user.agent.onboarding_completed?, false
  end

  def test_avatar_changes
    @controller.stubs(:params).returns(user: { avatar_attributes: { _destroy: '1' } })
    assert_equal @controller.safe_send('avatar_changes'), :destroy
    @controller.stubs(:params).returns(user: { avatar_attributes: { _destroy: '0' } })
    assert_equal @controller.safe_send('avatar_changes'), :upsert
  ensure
    @controller.unstub(:params)
  end
end
