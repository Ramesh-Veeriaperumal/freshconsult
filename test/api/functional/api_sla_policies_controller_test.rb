require_relative '../test_helper'
class ApiSlaPoliciesControllerTest < ActionController::TestCase
  include Helpers::SlaPoliciesTestHelper
  def wrap_cname(params)
    { api_sla_policy: params }
  end

  def test_index_load_sla_policies
    get :index, controller_params
    pattern = []
    Account.current.sla_policies.all.each do |sp|
      pattern << sla_policy_pattern(sp)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_update_company_sla_policies
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: { company_ids: [company.id] })
    assert_response 200
    match_json(sla_policy_pattern(sla_policy.reload))
  end

  def test_update_remove_company_sla_policy
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: { company_ids: [] })
    assert_response 200
    match_json(sla_policy_pattern(sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { group_ids: [1] } }, sla_policy))
  end

  def test_update_with_invalid_fields_in_conditions_hash
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: { group_ids: [1, 2], product_id: [1] })
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :invalid_field),
                bad_request_error_pattern('product_id', :invalid_field)])
  end

  def test_update_with_invalid_company_ids
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: { company_ids: [10_000, 1_000_001] })
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_update_with_invalid_company_ids_data_type
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: { company_ids: '1,2' })
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :data_type_mismatch, data_type: 'Array')])
  end

  def test_update_with_empty_conditions
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: {})
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :required_and_data_type_mismatch, data_type: 'Array')])
  end

  def test_update_with_nil_conditions
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: {})
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :required_and_data_type_mismatch, data_type: 'Array')])
  end

  def test_update_emptying_conditions_with_blank_company_ids
    company = create_company
    sla_policy = create_sla_policy_with_only_company_ids
    put :update, construct_params({ id: sla_policy.id }, applicable_to: nil)
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :data_type_mismatch, data_type: 'key/value pair')])
  end

  def test_update_default_sla_policy
    company = create_company
    put :update, construct_params({ id: 1 }, applicable_to: { company_ids: [company.id] })
    assert_response 400
    match_json(request_error_pattern('cannot_update_default_sla'))
  end

  def test_update_with_invalid_fields
    company = create_company
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, conditions: { company_id: [company.id] })
    assert_response 400
    match_json([bad_request_error_pattern('conditions', :invalid_field)])
  end

  def test_update_with_invalid_data_type
    sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: sla_policy.id }, applicable_to: [1, 2])
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :data_type_mismatch, data_type: 'key/value pair')])
  end

  def test_index_with_link_header
    3.times do
      quick_create_sla_policy
    end
    per_page = Account.current.sla_policies.all.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/sla_policies?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
