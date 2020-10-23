require_relative '../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Fdadmin::AccountsControllerTest < ActionController::TestCase
  include Fdadmin::FeatureMethods

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.nil? ? create_test_account : Account.first.make_current
  end

  def stub_validations_for_api_call
    Account.stubs(:current).returns(@account)
    ShardMapping.stubs(:find).returns(ShardMapping.first)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    FreshopsSubdomains.stubs(:include?).returns(true)
    Fdadmin::DevopsMainController.stubs(:verify_signature).returns(nil)
    Fdadmin::DevopsMainController.stubs(:permit_internal_tools_ip).returns(nil)
    $redis_routes.stubs(:perform_redis_op).returns(true)
  end

  def unstub_validations_for_api_call
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    FreshopsSubdomains.unstub(:include?)
    ShardMapping.unstub(:find)
    Fdadmin::DevopsMainController.unstub(:verify_signature)
    Fdadmin::DevopsMainController.unstub(:permit_internal_tools_ip)
    $redis_routes.unstub(:perform_redis_op)
  end

  def test_account_detail_with_id
    stub_validations_for_api_call
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :show, construct_params(params)
    assert_response 200
  ensure
    unstub_validations_for_api_call
  end

  def test_account_detail_with_domain
    stub_validations_for_api_call
    domain_name = @account.full_domain
    params = { version: 'v1', domain_name: domain_name, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :show, construct_params(params)
    assert_response 200
  ensure
    unstub_validations_for_api_call
  end

  def test_account_detail_with_id_for_invalid_key
    Account.stubs(:current).returns(@account)
    ShardMapping.stubs(:find).returns(ShardMapping.first)
    id = @account.id
    params = { account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :show, construct_params(params)
    assert_response 401
  ensure
    Account.unstub(:current)
    ShardMapping.unstub(:find)
  end

  def test_account_detail_with_domain_for_invalid_key
    Account.stubs(:current).returns(@account)
    ShardMapping.stubs(:find).returns(ShardMapping.first)
    domain_name = @account.full_domain
    params = { domain_name: domain_name, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :show, construct_params(params)
    assert_response 401
  ensure
    Account.unstub(:current)
    ShardMapping.unstub(:find)
  end

  def test_disabling_skip_mandatory_checks
    stub_validations_for_api_call
    id = @account.id
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = true
    @account.account_additional_settings.save!
    params = { 'account_id' => @account.id, 'operation' => 'rollback', 'digest' => 'xyz', 'name_prefix' => 'fdadmin_', 'path_prefix' => nil, 'action' => 'skip_mandatory_checks', 'controller' => 'fdadmin/accounts' }
    post :skip_mandatory_checks, construct_params(params)
    @account.account_additional_settings.reload
    assert_response 200
    assert_equal @account.account_additional_settings.additional_settings[:skip_mandatory_checks], false
  ensure
    unstub_validations_for_api_call
  end

  def test_enabling_skip_mandatory_checks
    stub_validations_for_api_call
    id = @account.id
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    @account.account_additional_settings.save!
    params = { 'account_id' => @account.id, 'operation' => 'launch', 'digest' => 'xyz', 'name_prefix' => 'fdadmin_', 'path_prefix' => nil, 'action' => 'skip_mandatory_checks', 'controller' => 'fdadmin/accounts' }
    post :skip_mandatory_checks, construct_params(params)
    @account.account_additional_settings.reload
    assert_response 200
    assert_equal @account.account_additional_settings.additional_settings[:skip_mandatory_checks], true
  ensure
    unstub_validations_for_api_call
  end

  def test_skip_mandatory_checks_with_invalid_operation
    stub_validations_for_api_call
    id = @account.id
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = true
    @account.account_additional_settings.save!
    params = { 'account_id' => @account.id, 'operation' => 'abcd', 'digest' => 'xyz', 'name_prefix' => 'fdadmin_', 'path_prefix' => nil, 'action' => 'skip_mandatory_checks', 'controller' => 'fdadmin/accounts' }
    post :skip_mandatory_checks, construct_params(params)
    @account.account_additional_settings.reload
    assert_response 400
    assert_equal @account.account_additional_settings.additional_settings[:skip_mandatory_checks], true
  ensure
    unstub_validations_for_api_call
  end

  def test_make_account_admin_success
    stub_validations_for_api_call
    agent = add_test_agent(@account, role: @account.roles.find_by_name('Agent').id)
    params = { 'version' => 'v1', 'account_id' => @account.id, 'email' => agent.email, 'digest' => 'xyz', 'name_prefix' => 'fdadmin_', 'path_prefix' => nil, 'action' => 'make_account_admin', 'controller' => 'fdadmin/accounts' }
    post :make_account_admin, construct_params(params)
    assert_response 200
    assert_equal true, @account.users.find_by_email(agent.email).roles.include?(@account.roles.find_by_name('Account Administrator'))
  ensure
    unstub_validations_for_api_call
  end

  def test_validate_and_fix_freshid
    Account.stubs(:current).returns(@account)
    OpenSSL::HMAC.stubs(:hexdigest).returns('xyz')
    FreshopsSubdomains.stubs(:include?).returns(true)

    # clean previous run keys
    redis_key = format(FRESHID_VALIDATION_TIMEOUT, account_id: @account.id.to_s)
    remove_others_redis_key(redis_key)

    $redis_routes.stubs(:perform_redis_op).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    params = { 'version' => 'v1', 'account_id' => @account.id, 'doer-email' => 'sample-invalid@freshdesk.dev', 'digest' => 'xyz', 'name_prefix' => 'fdadmin_', 'path_prefix' => nil, 'action' => 'validate_and_fix_freshid', 'controller' => 'fdadmin/accounts' }
    post :validate_and_fix_freshid, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal 'success', response['status']
  ensure
    $redis_routes.unstub(:perform_redis_op)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.unstub(:current)
    OpenSSL::HMAC.unstub(:hexdigest)
    FreshopsSubdomains.unstub(:include?)
  end

  def test_check_eligibility_for_omni_upgrade
    stub_validations_for_api_call
    domain_name = @account.full_domain
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Fdadmin::AccountsController.any_instance.stubs(:freshchat_and_freshcaller_integrated?).returns(false)
    Fdadmin::AccountsController.any_instance.stubs(:integrated_accounts_present_in_org?).returns(false)
    Fdadmin::AccountsController.any_instance.stubs(:fd_agents_are_superset_of_fch_agents?).returns(false)
    Fdadmin::AccountsController.any_instance.stubs(:fd_agents_are_superset_of_fcl_agents?).returns(false)

    params = { version: 'v1', account_id: @account.id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Freshid org v2 not enabled.', response['reason']


    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    params = { version: 'v1', account_id: @account.id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Freshchat or Freshcaller or both not integrated.', response['reason']

    Account.any_instance.stubs(:omni_accounts_present_in_org?).returns(true)
    params = { version: 'v1', account_id: @account.id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil }
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Freshcaller or Freshchat or both are present in organization but not integrated.', response['reason']

    Fdadmin::AccountsController.any_instance.stubs(:freshchat_and_freshcaller_integrated?).returns(true)
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Integrated freshchat or freshcaller or both accounts are not present in organization.', response['reason']

    Fdadmin::AccountsController.any_instance.stubs(:integrated_accounts_present_in_org?).returns(true)
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Some Freshchat agents are not added to Freshdesk.', response['reason']

    Fdadmin::AccountsController.any_instance.stubs(:fd_agents_are_superset_of_fch_agents?).returns(true)
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal false, response['status']
    assert_equal 'Some Freshcaller agents are not added to Freshdesk.', response['reason']

    Fdadmin::AccountsController.any_instance.stubs(:fd_agents_are_superset_of_fcl_agents?).returns(true)
    get :check_eligibility_for_omni_upgrade, construct_params(params)
    assert_response 200
    response = parse_response @response.body
    assert_equal true, response['status']
  ensure
    unstub_validations_for_api_call
    Fdadmin::AccountsController.unstub(:freshchat_and_freshcaller_integrated?)
    Fdadmin::AccountsController.unstub(:integrated_accounts_present_in_org?)
    Fdadmin::AccountsController.unstub(:fd_agents_are_superset_of_fcl_agents?)
    Fdadmin::AccountsController.unstub(:fd_agents_are_superset_of_fch_agents?)
    Account.unstub(:freshid_org_v2_enabled?)
    Account.unstub(:omni_accounts_present_in_org?)
  end

  # Add / Remove selectable feature test cases

  def test_add_selectable_feature
    stub_validations_for_api_call
    selectable_feature = SELECTABLE_FEATURES_LIST.first
    id = @account.id
    @account.revoke_feature selectable_feature
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: selectable_feature }
    put :add_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    assert Account.first.has_feature? selectable_feature
  ensure
    @account.revoke_feature selectable_feature
    unstub_validations_for_api_call
  end

  def test_add_invalid_selectable_feature
    stub_validations_for_api_call
    setting = INTERNAL_SETTINGS.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: setting }
    put :add_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    unstub_validations_for_api_call
  end

  def test_reenabled_selectable_feature
    stub_validations_for_api_call
    selectable_feature = SELECTABLE_FEATURES_LIST.first
    @account.add_feature selectable_feature
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: selectable_feature }
    put :add_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    @account.revoke_feature selectable_feature
    unstub_validations_for_api_call
  end

  def test_remove_selectable_feature
    stub_validations_for_api_call
    selectable_feature = SELECTABLE_FEATURES_LIST.first
    id = @account.id
    @account.add_feature selectable_feature
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: selectable_feature }
    put :remove_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    refute Account.first.has_feature? selectable_feature
  ensure
    unstub_validations_for_api_call
  end

  def test_remove_invalid_selectable_feature
    stub_validations_for_api_call
    setting = INTERNAL_SETTINGS.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: setting }
    put :remove_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    unstub_validations_for_api_call
  end

  def test_redisabled_selectable_feature
    stub_validations_for_api_call
    selectable_feature = SELECTABLE_FEATURES_LIST.first
    id = @account.id
    @account.revoke_feature selectable_feature if @account.has_feature? selectable_feature
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: selectable_feature }
    put :remove_selectable_feature, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    unstub_validations_for_api_call
  end

  # Add / Remove launch party test cases

  def test_add_launch_party
    stub_validations_for_api_call
    lp = (Account::LP_FEATURES - BLACKLISTED_LP_FEATURES).first
    id = @account.id
    @account.rollback lp
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :add_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    assert Account.first.launched? lp
  ensure
    @account.rollback lp
    unstub_validations_for_api_call
  end

  def test_add_invalid_launch_party
    stub_validations_for_api_call
    lp = BLACKLISTED_LP_FEATURES.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :add_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    @account.rollback lp
    unstub_validations_for_api_call
  end

  def test_reenable_launch_party
    stub_validations_for_api_call
    lp = (Account::LP_FEATURES - BLACKLISTED_LP_FEATURES).first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    @account.launch lp
    put :add_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    @account.rollback lp
    unstub_validations_for_api_call
  end

  def test_remove_launch_party
    stub_validations_for_api_call
    lp = (Account::LP_FEATURES - BLACKLISTED_LP_FEATURES).first
    id = @account.id
    @account.launch lp
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :remove_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    refute Account.first.launched? lp
  ensure
    unstub_validations_for_api_call
  end

  def test_remove_invalid_launch_party
    stub_validations_for_api_call
    lp = BLACKLISTED_LP_FEATURES.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :remove_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    unstub_validations_for_api_call
  end

  def test_redisable_launch_party
    stub_validations_for_api_call
    lp = (Account::LP_FEATURES - BLACKLISTED_LP_FEATURES).first
    id = @account.id
    @account.rollback lp if @account.launched? lp
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :remove_launch_party, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    unstub_validations_for_api_call
  end

  # Add / Remove setting test cases

  def test_add_setting
    stub_validations_for_api_call
    internal_setting = (INTERNAL_SETTINGS - BLACKLISTED_SETTINGS).first
    feature_dependency = SETTINGS_FEATURES[internal_setting]['feature_dependency']
    @account.add_feature feature_dependency
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: internal_setting }
    put :add_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    assert Account.first.safe_send("#{internal_setting}_enabled?")
  ensure
    @account.disable_setting internal_setting
    @account.revoke_feature feature_dependency
    unstub_validations_for_api_call
  end

  def test_add_invalid_setting
    stub_validations_for_api_call
    lp = BLACKLISTED_LP_FEATURES.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :add_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    unstub_validations_for_api_call
  end

  def test_reenable_setting
    stub_validations_for_api_call
    internal_setting = (INTERNAL_SETTINGS - BLACKLISTED_SETTINGS).first
    feature_dependency = SETTINGS_FEATURES[internal_setting]['feature_dependency']
    @account.add_feature feature_dependency
    @account.enable_setting internal_setting
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: internal_setting }
    put :add_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    @account.disable_setting internal_setting
    @account.revoke_feature feature_dependency
    unstub_validations_for_api_call
  end

  def test_remove_setting
    stub_validations_for_api_call
    internal_setting = (INTERNAL_SETTINGS - BLACKLISTED_SETTINGS).first
    feature_dependency = SETTINGS_FEATURES[internal_setting]['feature_dependency']
    @account.add_feature feature_dependency
    @account.enable_setting internal_setting
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: internal_setting }
    put :remove_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'success'
    refute Account.first.safe_send("#{internal_setting}_enabled?")
  ensure
    @account.revoke_feature feature_dependency
    unstub_validations_for_api_call
  end

  def test_remove_invalid_setting
    stub_validations_for_api_call
    lp = BLACKLISTED_LP_FEATURES.first
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: lp }
    put :remove_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'error'
  ensure
    unstub_validations_for_api_call
  end

  def test_redisable_setting
    stub_validations_for_api_call
    internal_setting = (INTERNAL_SETTINGS - BLACKLISTED_SETTINGS).first
    feature_dependency = SETTINGS_FEATURES[internal_setting]['feature_dependency']
    @account.add_feature feature_dependency
    id = @account.id
    params = { version: 'v1', account_id: id, digest: 'xyz', name_prefix: 'fdadmin_', path_prefix: nil,
               feature_name: internal_setting }
    put :remove_setting, construct_params(params)
    assert_response 200
    assert JSON.parse(response.body)['status'] == 'notice'
  ensure
    @account.revoke_feature feature_dependency
    unstub_validations_for_api_call
  end
end
