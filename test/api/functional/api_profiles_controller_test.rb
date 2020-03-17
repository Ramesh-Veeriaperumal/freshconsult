require_relative '../test_helper'
class ApiProfilesControllerTest < ActionController::TestCase
  include ProfilesTestHelper
  include AgentHelper

  def wrap_cname(params)
    { api_profile: params }
  end

  def test_show_profile
    currentuser = User.current
    get :show, construct_params(version: 'private', id: 'me')
    assert_response 200
    match_json(profile_pattern(currentuser.reload))
  end

  def test_api_agents_me
    currentuser = User.current
    get :show, construct_params(version: 'v2', id: 'me')
    assert_response 200
    match_json(profile_agent_pattern_with_additional_details(currentuser.reload))
  end

  def test_turn_on_shortcuts
    currentuser = User.current
    params_hash = { shortcuts_enabled: true }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    assert_response 200
    match_json(profile_pattern(currentuser.reload))
  end

  def test_turn_off_shortcuts
    currentuser = User.current
    params_hash = { shortcuts_enabled: false }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    assert_response 200
    match_json(profile_pattern(currentuser.reload))
  end

  def test_update_valid_profile_info
    currentuser = User.current
    ApiProfileValidation.any_instance.stubs(:multi_language_enabled?).returns(true)
    Account.any_instance.stubs(:multi_timezone_enabled?).returns(true)
    params_hash = { time_zone: 'Central Time (US & Canada)', language: 'hu', signature: Faker::Lorem.paragraph }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    assert_response 200
    match_json(profile_pattern(currentuser.reload))
  end

  def test_update_profile_name
    currentuser = User.current
    params_hash = { name: Faker::Lorem.paragraph }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    match_json([bad_request_error_pattern('name', :invalid_field)])
    assert_response 400
  end

  def test_update_profile_phone
    currentuser = User.current
    params_hash = { phone: '1234567890' }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    match_json([bad_request_error_pattern('phone', :invalid_field)])
    assert_response 400
  end

  def test_update_profile_mobile
    currentuser = User.current
    params_hash = { mobile: '1234567890' }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    match_json([bad_request_error_pattern('mobile', :invalid_field)])
    assert_response 400
  end


  def test_update_profile_error
    params_hash = { time_zone: 'Central Time (US & Canada)', language: 'hu', signature: Faker::Lorem.paragraph }
    Agent.any_instance.stubs(:update_attributes).returns(false)
    ApiProfileValidation.any_instance.stubs(:multi_language_enabled?).returns(true)
    Account.any_instance.stubs(:multi_timezone_enabled?).returns(true)
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    assert_response 500
  ensure
    Agent.any_instance.unstub(:update_attributes)
  end

  def test_reset_api_key_error
    params_hash = { time_zone: 'Central Time (US & Canada)', language: 'hu', signature: Faker::Lorem.paragraph }
    User.any_instance.stubs(:save!).raises(RuntimeError)
    put :reset_api_key, construct_params({ version: 'private', id: 'me' }, params_hash)
    assert_response 500
  ensure
    User.any_instance.unstub(:save!)
  end

  def test_update_profile_email
    currentuser = User.current
    params_hash = { email: Faker::Internet.email }
    put :update, construct_params({ version: 'private', id: 'me' }, params_hash)
    match_json([bad_request_error_pattern('email', :invalid_field)])
    assert_response 400
  end

  def test_reset_api_key
    currentuser = User.current
    post :reset_api_key, construct_params({ version: 'private', id: 'me' }, {})
    assert_response 200
    match_json(profile_pattern(currentuser.reload))
  end

  def test_meta_csrf_token
    Account.current.launch :freshid
    Account.current.reload
    get :show, controller_params({ version: 'private', id: 'me' }, {})
    assert_response 200
    assert_not_nil response.api_meta[:freshid_profile_url]
    Account.current.rollback :freshid
    Account.current.reload
  end
end
