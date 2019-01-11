require_relative '../test_helper'
class ApiSlaPoliciesControllerTest < ActionController::TestCase
  include SlaPoliciesTestHelper

  def setup
    super
    @sla_policy = nil
    @agent_1 = nil
    @agent_2 = nil
    @group = nil
  end

  after(:all) do
    if !@sla_policy.nil?
      @sla_policy.sla_details.delete_all if @sla_policy.sla_details.present?
      @sla_policy.delete 
    end
    @agent_1.delete if !@agent_1.nil?
    @agent_2.delete if !@agent_2.nil?
    @group.delete if !@group.nil?
  end

  def wrap_cname(params)
    { api_sla_policy: params }
  end

  def test_index_load_sla_policies
    get :index, controller_params
    pattern = []
    Account.current.sla_policies.each do |sp|
      pattern << sla_policy_pattern(sp)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

# ********************************************************* Company Validation

  def test_update_company_sla_policies
    @sla_policy = quick_create_sla_policy
    company = create_company
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_ids: [company.id] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_remove_company_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_ids: [], group_ids: [1] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { group_ids: [1] } }, @sla_policy))
  end

  def test_update_with_invalid_company_ids
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_ids: [10000, 1000001] })
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_update_with_invalid_company_ids_data_type
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_ids: '1,2' })
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :datatype_mismatch, expected_data_type: Array,
                                                 prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* Group Validation

  def test_update_group_sla_policies
    @sla_policy = quick_create_sla_policy
    @group = create_group(@account)
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { group_ids: [@group.id] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_remove_group_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { group_ids: [],company_ids: [3] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { company_ids: [3] } }, @sla_policy))
  end

  def test_update_with_invalid_group_ids
    @sla_policy = quick_create_sla_policy
    group_id_exist = Account.current.groups.pluck(:id).sort
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { group_ids: [10000, 1000001] })
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_update_with_invalid_group_ids_data_type
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { group_ids: '1,2' })
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :datatype_mismatch, expected_data_type: Array, 
                                            prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* product Validation

  def test_update_product_sla_policies
    @sla_policy = quick_create_sla_policy
    product = create_product
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { product_ids: [product.id] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_remove_product_sla_policy
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { product_ids: [],company_ids: [3] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { company_ids: [3] } }, @sla_policy))
  end

  def test_update_with_invalid_product_ids
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { product_ids: [10000, 1000001] })
    assert_response 400
    match_json([bad_request_error_pattern('product_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_update_with_invalid_product_ids_data_type
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { product_ids: '1,2' })
    assert_response 400
    match_json([bad_request_error_pattern('product_ids', :datatype_mismatch, expected_data_type: Array, 
                                              prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* sources Validation

  def test_update_source_sla_policies
    source_list = Hash[TicketConstants.source_names]
    source = 3
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { sources: [source] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_remove_source_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { sources: [],company_ids: [3] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { company_ids: [3] } }, @sla_policy))
  end

  def test_update_with_invalid_source
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { sources: [30, 81] })
    assert_response 400
    match_json([bad_request_error_pattern('sources', :invalid_list, list: '30, 81' )])
  end

  def test_update_with_invalid_source_data_type
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { sources: '1,2' })
    assert_response 400
    match_json([bad_request_error_pattern('sources', :datatype_mismatch, expected_data_type: Array,
                                           prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* ticket_types Validation

  def test_update_ticket_types_sla_policies
    ticket_type = "Question"
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { ticket_types: ["#{ticket_type}"] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_remove_ticket_types_sla_policy
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { ticket_types: [],product_ids: [product.id] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { product_ids: [product.id] } }, @sla_policy))
  end

  def test_update_with_invalid_ticket_types
    ticket_type = "NewType"
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { ticket_types: ["#{ticket_type}"] })
    assert_response 400
    match_json([bad_request_error_pattern('ticket_types', :invalid_list, list: 'NewType')])
  end

  def test_update_with_invalid_ticket_types_data_type
    product = create_product
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { ticket_types: 1 })
    assert_response 400
    match_json([bad_request_error_pattern('ticket_types', :datatype_mismatch, expected_data_type: Array, 
                                                prepend_msg: :input_received, given_data_type: Integer)])
  end

# ********************************************************* SLA Target

  def test_update_sla_target_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_sla_target_with_missing_priority_2
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })    
    assert_response 400
    match_json([bad_request_error_pattern('priority_2', :datatype_mismatch, expected_data_type: 'key/value pair')])
  end


  def test_update_sla_target_without_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })    
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', :missing_field )])
  end

  def test_update_invalid_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3601, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', :Multiple_of_60 )])
  end

  def test_update_lessthen_900_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 360, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', "must be greater than or equal to 900" )])
  end

  def test_update_invalid_datatype_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: "test", resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String )])
  end

  def test_update_sla_target_without_resolve_within_sla_policy
    @sla_policy = create_complete_sla_policy
   put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', :missing_field )])
  end

  def test_update_invalid_resolve_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 1901, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', :Multiple_of_60 )])
  end

  def test_update_lessthen_900_resolve_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 101, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', "must be greater than or equal to 900")])
  end

  def test_update_invalid_datatype_resolve_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: "test", business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String )])
  end

  def test_update_invalid_datatype_resolve_and_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: "fresh", resolve_within: "test", business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern("sla_target[priority_4][respond_within]", :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String ),
                bad_request_error_pattern("sla_target[priority_4][resolve_within]", :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_invalid_datatype_business_hours_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 3600, business_hours: "false", escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][business_hours]', :datatype_mismatch, expected_data_type: 'Boolean', 
                                          prepend_msg: :input_received, given_data_type: String )])
  end

  def test_update_invalid_datatype_escalation_enabled_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: "true" },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][escalation_enabled]', :datatype_mismatch, expected_data_type: 'Boolean', 
                                          prepend_msg: :input_received, given_data_type: String )])
  end

  def test_update_lessthen900_and_invalid_respond_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 601, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', "must be greater than or equal to 900" )])
  end

  def test_update_lessthen900_and_invalid_resolve_within_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, resolve_within: 601, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                })
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', "must be greater than or equal to 900" )])
  end

# ********************************************************* Escalations
 
 def test_update_Escalation_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_without_response_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "resolution": 
                                                                        {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}} }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_without_resolution_sla_policy 
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] } }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_without_resolution_and_response_sla_policy 
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {} ) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_with_empty_resolution_and_response_sla_policy 
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {"response": {}, "resolution":{}} ) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_without_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", :missing_field )])
  end

  def test_update_Escalation_without_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", :missing_field )])
  end

  def test_update_Escalation_invalid_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 780, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_update_Escalation_invalid_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 780, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000' )])
  end

  def test_update_Escalation_duplicate_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 1800, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[escalation_time]", :duplicate_not_allowed, name: 'escalation time', list: '1800'),
                bad_request_error_pattern("resolution[level_2][escalation_time]", :not_included, list: '3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_update_Escalation_invalid_response_Agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[8787] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_update_Escalation_invalid_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[8787]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :invalid_list, list: '8787')])
  end

  def test_update_Escalation_without_response_Agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0 },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :missing_field )])
  end

  def test_update_Escalation_without_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :missing_field )])
  end

  def test_update_empty_response_Agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0,agent_ids:[] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :blank )])
  end

  def test_update_empty_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0,agent_ids:[]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :blank )])
  end

  def test_update_Escalation_invalid_datatype_response_Agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:["test"] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_Escalation_invalid_datatype_resolution_agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:["test"]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_Escalation_with_2_resolution_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]}}
                                                                      }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_Escalation_with_5_resolution_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                                                                        "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]},
                                                                        "level_4": { escalation_time: 28800, agent_ids:[@agent_2.user_id]},
                                                                        "level_5": { escalation_time: 259200, agent_ids:[@agent_1.user_id]}}
                                                                      }) 
    assert_response 400
    match_json([bad_request_error_pattern('level_5', :invalid_field )])
  end

# ********************************************************* Name Discraption and Active

  def test_update_name_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, name: Faker::Lorem.word )
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_with_invalid_name_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, name: [12345])
    assert_response 400
    match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: String, 
                                          prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_description_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, description: "This sla is related to unit test")
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_with_invalid_description_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, description: [12,21,212])
    assert_response 400
    match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String,
                                                  prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_name_and_description_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, name: "Test_name", description: "This sla is related to unit test")
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_active_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, active: false)
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_invalid_datatype_active_sla_policy
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, active: "false")
    assert_response 400
    match_json([bad_request_error_pattern('active',:datatype_mismatch, expected_data_type: 'Boolean', 
                                          prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* Mixed

  def test_update_with_invalid_fields_in_conditions_hash
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { group_id: [1, 2], product_id: [1] })
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :invalid_field),
                bad_request_error_pattern('product_id', :invalid_field)])
  end

  def test_update_with_nil_conditions
    company = create_company
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: {})
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :blank, code: :invalid_field)])
  end

  def test_update_default_sla_policy
    company = create_company
    put :update, construct_params({ id: 1 }, applicable_to: { company_ids: [company.id] })
    assert_response 400
    match_json(request_error_pattern('cannot_update_default_sla'))
  end

  def test_update_with_invalid_fields
    company = create_company
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, conditions: { company_ids: [company.id] })
    assert_response 400
    match_json([bad_request_error_pattern('conditions', :invalid_field)])
  end

  def test_update_with_invalid_data_type
    @sla_policy = quick_create_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: [1, 2])
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :datatype_mismatch, expected_data_type: 'key/value pair',
                                                 prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_index_with_link_header
    array_sla_policy = []
    3.times do
      array_sla_policy << quick_create_sla_policy
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
    array_sla_policy.each do |_sla_policy|
      if !_sla_policy.nil?
        _sla_policy.sla_details.delete_all if _sla_policy.sla_details.present?
        _sla_policy.delete 
      end
    end
  end

  def get_agents
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} ) if @agent_1.nil?
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} ) if @agent_2.nil?
  end

end
