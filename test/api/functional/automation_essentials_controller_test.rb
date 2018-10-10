require_relative '../test_helper'
class AutomationEssentialsControllerTest < ActionController::TestCase

  VALID_FEATURES = [:onboarding_inlinemanual, :skip_portal_cname_chk, :new_onboarding, :ner]
  INVALID_FEATURES = [:invalid_feature, :dummy_feature, :test_feature]

  def test_lp_launch
    assert_equal Account.current.launched?(@test_feature_name), false
    put :lp_launch, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 200
    assert_equal Account.current.launched?(@test_feature_name), true
    match_json(features: Account.current.all_launched_features)
  end

  def test_lp_rollback
    Account.current.launch(@test_feature_name)
    assert_equal Account.current.launched?(@test_feature_name), true
    put :lp_rollback, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 200
    assert_equal Account.current.launched?(@test_feature_name), false
    match_json(features: Account.current.all_launched_features)
  end

  def test_lp_launched_features
    launched_features = Account.current.all_launched_features
    assert_equal launched_features.any?, true
    get :lp_launched_features, controller_params(version: 'v2')
    assert_response 200
    match_json(features: launched_features)
  end

  def test_lp_launch_for_production_env
    assert_equal Account.current.launched?(@test_feature_name), false
    Rails.env.stubs(:production?).returns(true)
    put :lp_launch, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@test_feature_name), false
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_lp_rollback_for_production_env
    Account.current.launch(@test_feature_name)
    assert_equal Account.current.launched?(@test_feature_name), true
    Rails.env.stubs(:production?).returns(true)
    put :lp_rollback, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@test_feature_name), true
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_lp_launched_features_for_production_env
    Rails.env.stubs(:production?).returns(true)
    get :lp_launched_features, controller_params(version: 'v2')
    assert_response 400
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_lp_launch_without_privilege
    assert_equal Account.current.launched?(@test_feature_name), false
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :lp_launch, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 403
    assert_equal Account.current.launched?(@test_feature_name), false
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_lp_rollback_without_privilege
    Account.current.launch(@test_feature_name)
    assert_equal Account.current.launched?(@test_feature_name), true
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :lp_rollback, controller_params(version: 'v2', feature: @test_feature_name)
    assert_response 403
    assert_equal Account.current.launched?(@test_feature_name), true
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_lp_launched_features_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    get :lp_launched_features, controller_params(version: 'v2')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_lp_launch_without_params
    assert_equal Account.current.launched?(@test_feature_name), false
    put :lp_launch, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.launched?(@test_feature_name), false
    match_json(request_error_pattern(:missing_params))
  end

  def test_lp_rollback_without_params
    Account.current.launch(@test_feature_name)
    assert_equal Account.current.launched?(@test_feature_name), true
    put :lp_rollback, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.launched?(@test_feature_name), true
    match_json(request_error_pattern(:missing_params))
  end

  def test_lp_launch_with_invalid_params
    assert_equal Account.current.launched?(@invalid_feature_name), false
    put :lp_launch, controller_params(version: 'v2', feature: @invalid_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@invalid_feature_name), false
    match_json(request_error_pattern(:invalid_values, fields: 'feature'))
  end

  def test_lp_rollback_with_invalid_params
    Account.current.launch(@invalid_feature_name)
    assert_equal Account.current.launched?(@invalid_feature_name), true
    put :lp_rollback, controller_params(version: 'v2', feature: @invalid_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@invalid_feature_name), true
    match_json(request_error_pattern(:invalid_values, fields: 'feature'))
  end

  def setup
    super
    @test_feature_name = VALID_FEATURES.sample
    @invalid_feature_name = INVALID_FEATURES.sample
    Account.current.rollback(@test_feature_name)
    Account.current.rollback(@invalid_feature_name)
  end
end
