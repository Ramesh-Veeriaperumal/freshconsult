require_relative '../../test_helper'
class Ember::SlaPoliciesControllerTest < ActionController::TestCase
  include SlaPoliciesTestHelper

  def setup
    super
    CustomRequestStore.store[:private_api_request] = true
    @sla_policy = nil
    @account.stubs(:sla_policy_revamp_enabled?).returns(true)
    @account.stubs(:next_response_sla_enabled?).returns(false)
  end

  after(:all) do
    @sla_policy.destroy if @sla_policy.present?
    Account.any_instance.unstub(:sla_policy_revamp_enabled?)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end
  # ************************************************** Test Index
  def test_index_with_sla_policy_revamp_feature
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.sla_policies.each do |sp|
      pattern << sla_policy_pattern(sp)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_index_without_sla_policy_revamp_feature
    @account.stubs(:sla_policy_revamp_enabled?).returns(false)
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.sla_policies.each do |sp|
      pattern << sla_policy_pattern(sp)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  # ************************************************** Test Show
  def test_show_with_sla_policy_revamp_feature
    @sla_policy = create_complete_sla_policy
    get :show, controller_params(id: @sla_policy.id, version: 'private')
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_show_without_sla_policy_revamp_feature
    @account.stubs(:sla_policy_revamp_enabled?).returns(false)
    @sla_policy = create_complete_sla_policy
    get :show, controller_params(id: @sla_policy.id, version: 'private')
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  # ************************************************** Test Create
  def test_create_new_format_with_sla_policy_revamp_feature
    params_hash = create_sla_params_hash_with_company(true)
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 201
    response = parse_response @response.body
    assert_equal 11, response.size
    @sla_policy = Helpdesk::SlaPolicy.find(response['id'])
    match_json(sla_policy_pattern(@sla_policy))
  end

  def test_create_old_format_with_sla_policy_revamp_feature
    params_hash = create_sla_params_hash_with_company
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 400
    match_json([bad_request_error_pattern('respond_within', :invalid_field), bad_request_error_pattern('resolve_within', :invalid_field)])
  end

  def test_create_new_format_without_sla_policy_revamp_feature
    @account.stubs(:sla_policy_revamp_enabled?).returns(false)
    params_hash = create_sla_params_hash_with_company(true)
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 400
    match_json([bad_request_error_pattern('first_response_time', :invalid_field), bad_request_error_pattern('resolution_due_time', :invalid_field)])
  end

  def test_create_with_next_response_sla_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    params_hash = create_sla_params_hash_with_company(true)
    params_hash[:sla_target] = {
      priority_4: { first_response_time: 'PT15M', every_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true },
      priority_3: { first_response_time: 'PT20M', every_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: true, escalation_enabled: true },
      priority_2: { first_response_time: 'PT30M', every_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: false, escalation_enabled: true },
      priority_1: { first_response_time: 'PT1H', every_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true }
    }
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 201
    response = parse_response @response.body
    @sla_policy = Helpdesk::SlaPolicy.find(response['id'])
    assert_equal 11, response.size
    match_json(sla_policy_pattern(@sla_policy))
  end

  def test_create_without_next_response_sla_feature
    params_hash = create_sla_params_hash_with_company(true)
    params_hash[:sla_target] = {
      priority_4: { first_response_time: 'PT15M', every_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true },
      priority_3: { first_response_time: 'PT20M', every_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: true, escalation_enabled: true },
      priority_2: { first_response_time: 'PT30M', every_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: false, escalation_enabled: true },
      priority_1: { first_response_time: 'PT1H', every_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true }
    }
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 400
    match_json([
      bad_request_error_pattern('sla_target[priority_4][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_3][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_2][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_1][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time')
    ])
  end

  def test_create_with_invalid_company_name_data_type
    params_hash = create_sla_params_hash_with_company(true)
    params_hash[:applicable_to] = { company_ids: [100] }
    post :create, construct_params({ version: 'private' }.merge(params_hash))
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :array_datatype_mismatch, expected_data_type: String)])
  end

  # ************************************************** Test Update
  def test_update_sla_target_new_format_with_sla_policy_revamp_feature
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_sla_target_old_format_with_sla_policy_revamp_feature
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
        'priority_3': { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
        'priority_2': { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
        'priority_1': { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('respond_within', :invalid_field), bad_request_error_pattern('resolve_within', :invalid_field)])
  end

  def test_update_sla_target_new_format_without_sla_policy_revamp_feature
    @account.stubs(:sla_policy_revamp_enabled?).returns(false)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('first_response_time', :invalid_field), bad_request_error_pattern('resolution_due_time', :invalid_field)])
  end

  def test_update_unallowed_field_default_sla_policy
    company = create_company
    default_sla_id = Account.current.sla_policies.find_by_is_default(true).id
    put :update, construct_params(version: 'private', id: default_sla_id, applicable_to: { company_ids: [company.id] })
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :invalid_field)])
  end

  def test_update_allowed_field_default_sla_policy
    default_sla_policy = Account.current.sla_policies.find_by_is_default(true)
    put :update, construct_params(version: 'private', id: default_sla_policy.id, escalation: { response: { escalation_time: 3600, agent_ids:[-1] } })
    assert_response 200
    match_json(sla_policy_pattern(default_sla_policy.reload))
  end

  def test_update_sla_target_more_than_1_year
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT1H', resolution_due_time: 'P500D', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolution_due_time]', :must_be_less_than_1_year)])
  end

  def test_update_sla_target_less_than_15_minutes
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT10M', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][first_response_time]', :must_be_more_than_15_minutes)])
  end

  def test_update_sla_target_invalid_data_type
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 100, resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][first_response_time]', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer)])
  end

  def test_update_sla_target_invalid_format
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][first_response_time]', 'Must be in the valid ISO 8601 duration format - P[n]DT[n]H[n]M')])
  end

  def test_update_every_response_time_without_next_response_sla_feature
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT1H', every_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', every_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', every_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', every_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([
      bad_request_error_pattern('sla_target[priority_4][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_3][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_2][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time'),
      bad_request_error_pattern('sla_target[priority_1][every_response_time]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'every_response_time')
    ])
  end

  def test_update_every_response_time_with_next_response_sla_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_4': { first_response_time: 'PT1H', every_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', every_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', every_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', every_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_invalid_priority
    @sla_policy = create_complete_sla_policy
    put :update, construct_params(version: 'private', id: @sla_policy.id,
      sla_target: {
        'priority_5': { first_response_time: 'PT2H', resolution_due_time: 'PT2H', business_hours: false, escalation_enabled: true },
        'priority_4': { first_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
        'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
        'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
        'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern('priority_5', :invalid_field )])
  end

# ************************************************** Test Destroy
  def test_destroy_sla_policy
    @sla_policy = create_complete_sla_policy
    put :destroy, construct_params({ version: 'private', id: @sla_policy.id })
    assert_response 204
  end

  def test_destroy_default_sla_policy
    default_sla_id = Account.current.sla_policies.find_by_is_default(true).id
    put :destroy, construct_params({ version: 'private', id: default_sla_id })
    assert_response 400
    match_json(request_error_pattern('cannot_update_default_sla'))
  end

# ************************************************** Test reorder positon
  def test_correct_position_while_adding_sla_policy
    sla_policy_ids = []
    3.times do
      sla_policy_temp = quick_create_sla_policy
      sla_policy_ids << sla_policy_temp.id
    end
    sla_policies_count = @account.sla_policies.count
    sla_policy = quick_create_sla_policy
    sla_policy_ids << sla_policy.id
    assert_equal sla_policy.position, sla_policies_count + 1
  ensure
    delete_sla_policies(sla_policy_ids)
  end

  def test_update_position
    sla_policy_ids = []
    3.times do
      sla_policy_temp = quick_create_sla_policy
      sla_policy_ids << sla_policy_temp.id
    end
    sla_policy = quick_create_sla_policy
    sla_policy_ids << sla_policy.id
    updated_position = sla_policy.position - 2
    position_reorder = @account.sla_policies_reorder.pluck(:position)
    put :update, construct_params(id: sla_policy.id, version: 'private', applicable_to: { sources: [1] }, position: updated_position)
    assert_response 200
    sla_policy.reload
    assert_equal sla_policy.position, position_reorder[updated_position - 1]
  ensure
    delete_sla_policies(sla_policy_ids)
  end

  def test_visual_position
    sla_policy_1 = quick_create_sla_policy
    sla_policy_2 = quick_create_sla_policy
    sla_policy_ids = [sla_policy_1.id, sla_policy_2.id]
    sla_policy_1.active = false
    sla_policy_1.save
    get :index, controller_params(version: 'private')
    assert_response 200
    resp_body = JSON.parse(response.body)
    pattern = []
    Account.current.sla_policies_reorder.each do |sp|
      pattern << sla_policy_pattern(sp)
    end
    match_json(pattern.ordered!)
  ensure
    delete_sla_policies(sla_policy_ids)
  end

  def delete_sla_policies(sla_policy_ids)
    @account.sla_policies.where(id: sla_policy_ids).each do |sla_policy|
      sla_policy.destroy
    end
  end
end
