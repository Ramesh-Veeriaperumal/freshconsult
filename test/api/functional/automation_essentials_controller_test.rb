require_relative '../test_helper'
class AutomationEssentialsControllerTest < ActionController::TestCase

  VALID_LP_FEATURES = [:onboarding_inlinemanual, :skip_portal_cname_chk, :new_onboarding, :ner]
  VALID_BITMAP_FEATURES = [:split_tickets, :add_watcher, :multi_product, :multiple_user_companies]
  INVALID_FEATURES = [:invalid_feature, :dummy_feature, :test_feature]

  def test_lp_launch
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    put :lp_launch, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 200
    assert_equal Account.current.launched?(@test_lp_feature_name), true
    match_json(features: Account.current.all_launched_features)
  end

  def test_lp_rollback
    Account.current.launch(@test_lp_feature_name)
    assert_equal Account.current.launched?(@test_lp_feature_name), true
    put :lp_rollback, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 200
    assert_equal Account.current.launched?(@test_lp_feature_name), false
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
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    Rails.env.stubs(:production?).returns(true)
    put :lp_launch, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_lp_rollback_for_production_env
    Account.current.launch(@test_lp_feature_name)
    assert_equal Account.current.launched?(@test_lp_feature_name), true
    Rails.env.stubs(:production?).returns(true)
    put :lp_rollback, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 400
    assert_equal Account.current.launched?(@test_lp_feature_name), true
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
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :lp_launch, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 403
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_lp_rollback_without_privilege
    Account.current.launch(@test_lp_feature_name)
    assert_equal Account.current.launched?(@test_lp_feature_name), true
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :lp_rollback, controller_params(version: 'v2', feature: @test_lp_feature_name)
    assert_response 403
    assert_equal Account.current.launched?(@test_lp_feature_name), true
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
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    put :lp_launch, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.launched?(@test_lp_feature_name), false
    match_json(request_error_pattern(:missing_params))
  end

  def test_lp_rollback_without_params
    Account.current.launch(@test_lp_feature_name)
    assert_equal Account.current.launched?(@test_lp_feature_name), true
    put :lp_rollback, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.launched?(@test_lp_feature_name), true
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

  def test_bitmap_add_feature
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    put :bitmap_add_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 200
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    match_json(features: Account.current.enabled_features_list)
  end

  def test_bitmap_revoke_feature
    Account.current.add_feature(@test_bitmap_feature_name)
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    put :bitmap_revoke_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 200
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    match_json(features: Account.current.enabled_features_list)
  end

  def test_bitmap_features_list
    launched_features = Account.current.enabled_features_list
    assert_equal launched_features.any?, true
    get :features_list, controller_params(version: 'v2')
    assert_response 200
    match_json(features: Account.current.enabled_features_list)
  end

  def test_execurte_script_get_features_list
    put :execute_script, controller_params(version: 'v2',script_to_execute: 'Account.current.enabled_features_list')
    assert_response 200
    match_json(result: Account.current.enabled_features_list)
  end

  def test_bitmap_add_feature_for_production_env
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    Rails.env.stubs(:production?).returns(true)
    put :bitmap_add_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 400
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_bitmap_revoke_feature_for_production_env
    Account.current.add_feature(@test_bitmap_feature_name)
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    Rails.env.stubs(:production?).returns(true)
    put :bitmap_revoke_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 400
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_bitmap_features_list_for_production_env
    Rails.env.stubs(:production?).returns(true)
    get :features_list, controller_params(version: 'v2')
    assert_response 400
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def test_bitmap_add_feature_without_privilege
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :bitmap_add_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 403
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_bitmap_revoke_feature_without_privilege
    Account.current.add_feature(@test_bitmap_feature_name)
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :bitmap_revoke_feature, controller_params(version: 'v2', feature: @test_bitmap_feature_name)
    assert_response 403
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_bitmap_features_list_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    get :features_list, controller_params(version: 'v2')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
  end

  def test_bitmap_add_feature_without_params
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    put :bitmap_add_feature, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), false
    match_json(request_error_pattern(:missing_params))
  end

  def test_bitmap_revoke_feature_without_params
    Account.current.add_feature(@test_bitmap_feature_name)
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    put :bitmap_revoke_feature, controller_params(version: 'v2')
    assert_response 400
    assert_equal Account.current.send("#{@test_bitmap_feature_name}_enabled?"), true
    match_json(request_error_pattern(:missing_params))
  end

  def test_bitmap_add_feature_with_invalid_params
    put :bitmap_add_feature, controller_params(version: 'v2', feature: @invalid_feature_name)
    assert_response 400
    match_json(request_error_pattern(:invalid_values, fields: 'feature'))
  end

  def test_bitmap_revoke_feature_with_invalid_params
    put :bitmap_revoke_feature, controller_params(version: 'v2', feature: @invalid_feature_name)
    assert_response 400
    match_json(request_error_pattern(:invalid_values, fields: 'feature'))
  end

  def test_execute_script_for_production_env
    Rails.env.stubs(:production?).returns(true)
    put :execute_script, controller_params(version: 'v2', script_to_execute: 'Account.find(2).make_current')
    assert_response 400
    match_json(request_error_pattern(:unsupported_environment))
    Rails.env.unstub(:production?)
  end

  def setup
    super
    @test_lp_feature_name = VALID_LP_FEATURES.sample
    @invalid_feature_name = INVALID_FEATURES.sample
    @test_bitmap_feature_name = VALID_BITMAP_FEATURES.sample
    Account.current.rollback(@test_lp_feature_name)
    Account.current.rollback(@invalid_feature_name)
    Account.current.revoke_feature(@test_bitmap_feature_name)
  end
end
