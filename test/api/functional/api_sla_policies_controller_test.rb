require_relative '../test_helper'
class ApiSlaPoliciesControllerTest < ActionController::TestCase
  include SlaPoliciesTestHelper

  def setup
    CustomRequestStore.store[:private_api_request] = false
    super
    Language.stubs(:current).returns(Language.find_by_code('en'))
    @sla_policy = nil
    @agent_1 = nil
    @agent_2 = nil
    @group = nil
    @account.stubs(:segments_enabled?).returns(true)
    @account.stubs(:sla_management_enabled?).returns(true)
  end

  after(:all) do
    if !@sla_policy.nil?
      @sla_policy.sla_details.delete_all if @sla_policy.sla_details.present?
      @sla_policy.delete 
    end
    @agent_1.delete if !@agent_1.nil?
    @agent_2.delete if !@agent_2.nil?
    @group.delete if !@group.nil?
    @account.unstub(:segments_enabled?)
    @account.unstub(:sla_management_enabled?)
    Language.unstub(:current)
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
    group_id = @account.groups.last.id || create_group(@account).id
    put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_ids: [], group_ids: [group_id] })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    match_json(sla_policy_pattern({ applicable_to: { group_ids: [group_id] } }, @sla_policy))
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

  # ********************************************************* Contact Segments Validation

    def test_update_contact_segments_sla_policies
      @sla_policy = quick_create_sla_policy
      contact_segment = create_contact_segment
      put :update, construct_params({ id: @sla_policy.id }, applicable_to: { contact_segments: [contact_segment.id] })
      assert_response 200
      match_json(sla_policy_pattern(@sla_policy.reload))
    end

    def test_update_remove_contact_segments_sla_policy
      @sla_policy = quick_create_sla_policy
      group_id = @account.groups.last.id || create_group(@account).id
      put :update, construct_params({ id: @sla_policy.id }, applicable_to: { contact_segments: [], group_ids: [group_id] })
      assert_response 200
      match_json(sla_policy_pattern(@sla_policy.reload))
      match_json(sla_policy_pattern({ applicable_to: { group_ids: [group_id] } }, @sla_policy))
    end

    def test_update_with_invalid_contact_segments
      @sla_policy = quick_create_sla_policy
      put :update, construct_params({ id: @sla_policy.id }, applicable_to: { contact_segments: [10000, 1000001] })
      assert_response 400
      match_json([bad_request_error_pattern('contact_segments', :invalid_list, list: '10000, 1000001')])
    end

    def test_update_with_invalid_contact_segments_data_type
      @sla_policy = quick_create_sla_policy
      put :update, construct_params({ id: @sla_policy.id }, applicable_to: { contact_segments: '1,2' })
      assert_response 400
      match_json([bad_request_error_pattern('contact_segments', :datatype_mismatch, expected_data_type: Array,
                                                   prepend_msg: :input_received, given_data_type: String)])
    end

    # ********************************************************* Company Segments Validation

      def test_update_company_segments_sla_policies
 
        @sla_policy = quick_create_sla_policy
        company_segment = create_company_segment
        put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_segments: [company_segment.id] })
        assert_response 200
        match_json(sla_policy_pattern(@sla_policy.reload))
      end

      def test_update_remove_company_segments_sla_policy
 
        @sla_policy = quick_create_sla_policy
        group_id = @account.groups.last.id || create_group(@account).id
        put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_segments: [], group_ids: [group_id] })
        assert_response 200
        match_json(sla_policy_pattern(@sla_policy.reload))
        match_json(sla_policy_pattern({ applicable_to: { group_ids: [group_id] } }, @sla_policy))
      end

      def test_update_with_invalid_company_segments
 
        @sla_policy = quick_create_sla_policy
        put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_segments: [10000, 1000001] })
        assert_response 400
        match_json([bad_request_error_pattern('company_segments', :invalid_list, list: '10000, 1000001')])
      end

      def test_update_with_invalid_company_segments_data_type
 
        @sla_policy = quick_create_sla_policy
        put :update, construct_params({ id: @sla_policy.id }, applicable_to: { company_segments: '1,2' })
        assert_response 400
        match_json([bad_request_error_pattern('company_segments', :datatype_mismatch, expected_data_type: Array,
                                                     prepend_msg: :input_received, given_data_type: String)])
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

  def test_update_new_format_sla_target_sla_policy
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
      'priority_4': { first_response_time: 'PT1H', resolution_due_time: 'PT1H', business_hours: false, escalation_enabled: true },
      'priority_3': { first_response_time: 'PT30M', resolution_due_time: 'PT30M', business_hours: true, escalation_enabled: true },
      'priority_2': { first_response_time: 'PT20M', resolution_due_time: 'PT20M', business_hours: false, escalation_enabled: true },
      'priority_1': { first_response_time: 'PT15M', resolution_due_time: 'PT15M', business_hours: false, escalation_enabled: true }
    })
    assert_response 400
    match_json([bad_request_error_pattern('first_response_time', :invalid_field), bad_request_error_pattern('resolution_due_time', :invalid_field)])
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

  def test_update_next_respond_within_without_feature
    @account.stubs(:next_response_sla_enabled?).returns(false)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, next_respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_3][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_2][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_1][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_next_respond_within_with_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, next_respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_invalid_datatype_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, next_respond_within: "test", resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String)])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_lessthan_900_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, next_respond_within: 600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', 'must be greater than or equal to 900')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_invalid_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    put :update, construct_params({ id: @sla_policy.id }, sla_target: {
                                  "priority_4": { respond_within: 3600, next_respond_within: 3601, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                                  "priority_3": { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                                  "priority_2": { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                                  "priority_1": { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }) 
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :Multiple_of_60)])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

# ********************************************************* Escalations
 
 def test_update_escalation_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_reminder_response_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_reminder_resolution_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_response_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_resolution_sla_policy 
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_resolution_and_response_sla_policy 
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {} ) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_with_empty_resolution_and_response_sla_policy 
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {"reminder_response": {}, "reminder_resolution":{}, "response": {}, "resolution":{}} ) 
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_without_reminder_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
     { "reminder_response": { agent_ids:[@agent_1.user_id] },
       "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
       "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
       "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                       "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                       "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                     }
     })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[escalation_time]", :missing_field )])
  end

  def test_update_escalation_without_reminder_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
     { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
       "reminder_resolution": { agent_ids:[@agent_1.user_id] },
       "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
       "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                       "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                       "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                     }
     })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[escalation_time]", :missing_field )])
  end

  def test_update_escalation_without_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", :missing_field )])
  end

  def test_update_escalation_without_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", :missing_field )])
  end

  def test_update_escalation_invalid_reminder_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
  end

  def test_update_escalation_invalid_reminder_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
  end

  def test_update_escalation_invalid_response_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 780, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_update_escalation_invalid_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 780, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000' )])
  end

  def test_update_escalation_duplicate_resolution_escalation_time_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 1800, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[escalation_time]", :duplicate_not_allowed, name: 'escalation time', list: '1800'),
                bad_request_error_pattern("resolution[level_2][escalation_time]", :not_included, list: '3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_update_escalation_invalid_reminder_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[8787] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_update_escalation_invalid_reminder_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[8787] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_update_escalation_invalid_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[8787] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_update_escalation_invalid_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[8787] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :invalid_list, list: '8787')])
  end

  def test_update_escalation_without_reminder_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600 },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :missing_field )])
  end

  def test_update_escalation_without_reminder_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600 },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :missing_field )])
  end

  def test_update_escalation_without_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0 },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :missing_field )])
  end

  def test_update_escalation_without_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0 },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :missing_field )])
  end

  def test_update_escalation_empty_reminder_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :blank )])
  end

  def test_update_escalation_empty_reminder_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :blank )])
  end

  def test_update_escalation_empty_response_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :blank )])
  end

  def test_update_escalation_empty_resolution_agent_id_sla_policy
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :blank )])
  end

  def test_update_escalation_invalid_datatype_reminder_response_agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:["test"] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_escalation_invalid_datatype_reminder_resolution_agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:["test"] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_escalation_invalid_datatype_response_agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:["test"] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_escalation_invalid_datatype_resolution_agent_id
    @sla_policy = create_complete_sla_policy
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} )
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:["test"] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
  end

  def test_update_escalation_with_2_resolution_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_2.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] }
                      }
      })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
  end

  def test_update_escalation_with_5_resolution_sla_policy
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  
      { "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
        "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
        "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_2.user_id] },
                        "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id] },
                        "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]},
                        "level_4": { escalation_time: 28800, agent_ids:[@agent_2.user_id]},
                        "level_5": { escalation_time: 259200, agent_ids:[@agent_1.user_id]}
                      }
      })
    assert_response 400
    match_json([bad_request_error_pattern('level_5', :invalid_field )])
  end

  def test_update_escalation_next_response_without_feature
    @account.stubs(:next_response_sla_enabled?).returns(false)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern('escalation_reminder_next_response', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'reminder_next_response'), bad_request_error_pattern('escalation_next_response', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_response')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
   end

  def test_update_escalation_next_response_with_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_only
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] } })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_empty
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "reminder_next_response": {} })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_only
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] } })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_empty
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  { "next_response": {} })
    assert_response 200
    match_json(sla_policy_pattern(@sla_policy.reload))
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_without_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[escalation_time]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_without_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("next_response[escalation_time]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_invalid_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_invalid_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 100, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("next_response[escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_without_agent_ids
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600 },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_without_agent_ids
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0 },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_invalid_datatype_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:["test"] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_invalid_datatype_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:["test"] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_invalid_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[10001] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :invalid_list, list: '10001' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_invalid_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    @sla_policy = create_complete_sla_policy
    get_agents
    put :update, construct_params({ id: @sla_policy.id }, "escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[10001] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
    })
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :invalid_list, list: '10001' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

# ********************************************************* Name Description and Active

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

# ********************************************************* Company Validation for create

  def test_create_sla_policy_with_company
    params_hash = create_sla_params_hash_with_company
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal 11, response.size
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_sla_policy_product_and_comapany
    params_hash = create_sla_params_hash_with_company_and_product
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    assert_equal 11, response.size
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    
  end

  def test_create_with_invalid_company_ids
    post :create, construct_params({ name:Faker::Lorem.word , applicable_to: { company_ids: [10000, 1000001] },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_create_with_invalid_company_ids_data_type
    post :create, construct_params(name: Faker::Lorem.word , applicable_to: { company_ids: '1,2' },sla_target:create_sla_target)
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_emptying_conditions_with_blank_company_ids
    post :create, construct_params(name: Faker::Lorem.word, applicable_to: nil,sla_target:create_sla_target)
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :blank, code: :invalid_field)])
  end

# ********************************************************* Group Validation for create
  def test_create_group_sla_policies
    group = create_group(@account)
    sla_target = create_sla_target
    params_hash = {name: Faker::Lorem.word, applicable_to: { group_ids: [group.id] },sla_target: sla_target}
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_with_invalid_group_ids
    group = create_group(@account)
    post :create, construct_params({name: Faker::Lorem.word, applicable_to: { group_ids: [10000, 1000001] },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_create_with_invalid_group_ids_data_type
    group = create_group(@account)
    post :create, construct_params({name: Faker::Lorem.word, applicable_to: { group_ids: '1,2' },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* product Validation for create

  def test_create_product_sla_policies
    product = create_product
    sla_target = create_sla_target
    params_hash = {name: Faker::Lorem.word, applicable_to: { product_ids: [product.id] },sla_target:sla_target}
    post :create, construct_params(params_hash)
    response = parse_response @response.body
    assert_response 201
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end


  def test_create_with_invalid_product_ids
    product = create_product
    params_hash = {name: Faker::Lorem.word, applicable_to: { product_ids: [10000, 1000001] },sla_target:create_sla_target}
    put :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('product_ids', :invalid_list, list: '10000, 1000001')])
  end

  def test_create_with_invalid_product_ids_data_type
    product = create_product
    post :create, construct_params({name: Faker::Lorem.word, applicable_to: { product_ids: '1,2' },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('product_ids', :datatype_mismatch, expected_data_type: Array, 
                                              prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* sources Validation for create

  def test_create_source_sla_policies
    source_list = Hash[TicketConstants.source_names]
    sla_target = create_sla_target
    source = 3
    params_hash = {name: Faker::Lorem.word, applicable_to: { sources: [source] },sla_target:sla_target}
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_with_invalid_source
    post :create, construct_params({ name: Faker::Lorem.word , applicable_to: { sources: [300] }})
    assert_response 400
    #match_json([bad_request_error_pattern('sources', :not_included, list: '1, 2, 3, 7, 8, 9, 10')])
  end

  def test_create_with_invalid_source_data_type
    post :create, construct_params({ name: Faker::Lorem.word , applicable_to: { sources: '1,2' },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('sources', :datatype_mismatch, expected_data_type: Array,prepend_msg: :input_received, given_data_type: String)])
  end

# ********************************************************* ticket_types Validation create

  def test_create_ticket_types_sla_policies
    ticket_type = "Question"
    params_hash = {name: Faker::Lorem.word ,applicable_to: { ticket_types: ["#{ticket_type}"] },sla_target:create_sla_target}
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end


  def test_create_with_invalid_ticket_types
    ticket_type = "NewType"
    post :create, construct_params({ name: Faker::Lorem.word , applicable_to: { ticket_types: ["#{ticket_type}"] },sla_target:create_sla_target}) 
    assert_response 400
    match_json([bad_request_error_pattern('ticket_types', :invalid_list,list:'NewType')])
  end

  def test_create_with_invalid_ticket_types_data_type
    post :create, construct_params({ name: Faker::Lorem.word , applicable_to: { ticket_types: 1 },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('ticket_types', :datatype_mismatch, expected_data_type: Array, 
                                                prepend_msg: :input_received, given_data_type: Integer)])
  end

  # ********************************************************* Contact Segment Validation for create

    def test_create_sla_policy_with_contact_segment
      contact_segment = create_contact_segment
      params_hash = { name: Faker::Lorem.word, applicable_to: { contact_segments: [contact_segment.id] }, sla_target:create_sla_target }
      post :create, construct_params(params_hash)
      assert_response 201
      response = parse_response @response.body
      match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
      Helpdesk::SlaPolicy.last.delete
    end

    def test_create_with_invalid_contact_segment_ids
      contact_segment = create_contact_segment
      post :create, construct_params({ name: Faker::Lorem.word, applicable_to: { contact_segments: [10000, 1000001] }, sla_target: create_sla_target })
      assert_response 400
      match_json([bad_request_error_pattern('contact_segments', :invalid_list, list: '10000, 1000001')])
    end

    def test_create_with_invalid_contact_segment_ids_data_type

      contact_segment = create_contact_segment
      post :create, construct_params({ name: Faker::Lorem.word, applicable_to: { contact_segments: '1,2' }, sla_target: create_sla_target })
      assert_response 400
      match_json([bad_request_error_pattern('contact_segments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    end

  # ********************************************************* Company Segment Validation for create

    def test_create_sla_policy_with_company_segment
      company_segment = create_company_segment
      params_hash = { name: Faker::Lorem.word, applicable_to: { company_segments: [company_segment.id] }, sla_target: create_sla_target }
      post :create, construct_params(params_hash)
      assert_response 201
      response = parse_response @response.body
      match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
      Helpdesk::SlaPolicy.last.delete
    end

    def test_create_with_invalid_company_segment_ids
      company_segment = create_company_segment
      post :create, construct_params({ name: Faker::Lorem.word, applicable_to: { company_segments: [10000, 1000001] }, sla_target: create_sla_target })
      assert_response 400
      match_json([bad_request_error_pattern('company_segments', :invalid_list, list: '10000, 1000001')])
    end

    def test_create_with_invalid_company_segment_ids_data_type
      company_segment = create_company_segment
      post :create, construct_params({ name: Faker::Lorem.word, applicable_to: { company_segments: '1,2' }, sla_target: create_sla_target })
      assert_response 400
      match_json([bad_request_error_pattern('company_segments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    end

# ********************************************************* SLA Target for create

  def test_create_sla_target_with_3_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({sla_target: { priority_4: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('priority_2', :datatype_mismatch, expected_data_type: 'key/value pair')])
  end


  def test_create_sla_target_without_respond_within_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {sla_target:{ priority_4: {resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("sla_target[priority_4][respond_within]",:missing_field)])
  end

  def test_create_invalid_respond_within_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {sla_target: {
                "priority_4": { respond_within: 3601, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                "priority_1": { respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
                                }})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', :Multiple_of_60 )])
  end

  def test_create_sla_target_without_resolve_within_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({sla_target: {
                "priority_4": { respond_within: 3600, resolve_within: 3600, business_hours: false, escalation_enabled: true },
                "priority_3": { respond_within: 1800, resolve_within: 1800, business_hours: true, escalation_enabled: true },
                "priority_2": { respond_within: 1200, resolve_within: 1200, business_hours: false, escalation_enabled: true },
                "priority_1": { respond_within: 900,  business_hours: false, escalation_enabled: true }}})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_1][resolve_within]', :missing_field )])
  end

  def test_create_invalid_resolve_within_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({sla_target:{ priority_4: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 1300,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_3][resolve_within]', :Multiple_of_60 )])
  end

  def test_create_invalid_priority_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {sla_target: { priority_4: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_14: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}
              })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('priority_14', :invalid_field )])
  end

  def test_create_sla_policy_with_target
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target:     { priority_4: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}}

    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_lessthen_900_respond_within_sla_policy
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target:     { priority_4: { respond_within: 300,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}}

    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][respond_within]', "must be greater than or equal to 900" )])
  end 

  def test_create_lessthen_900_resolve_within_sla_policy
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target:     { priority_4: { respond_within: 900,resolve_within: 300,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}}}

    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][resolve_within]', "must be greater than or equal to 900" )])
  end 
  def test_create_next_respond_within_without_feature
    @account.stubs(:next_response_sla_enabled?).returns(false)
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target: {
      priority_4: { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true },
      priority_3: { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: true, escalation_enabled: true },
      priority_2: { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: false, escalation_enabled: true },
      priority_1: { respond_within: 3600, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
    }}
    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_3][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_2][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within'),
    bad_request_error_pattern('sla_target[priority_1][next_respond_within]', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_respond_within')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_next_respond_within_with_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target: {
      priority_4: { respond_within: 900, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true },
      priority_3: { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: true, escalation_enabled: true },
      priority_2: { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: false, escalation_enabled: true },
      priority_1: { respond_within: 3600, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
    }}
    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_invalid_datatype_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target: {
      priority_4: { respond_within: 900, next_respond_within: "test", resolve_within: 900, business_hours: false, escalation_enabled: true },
      priority_3: { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: true, escalation_enabled: true },
      priority_2: { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: false, escalation_enabled: true },
      priority_1: { respond_within: 3600, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
    }}
    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :datatype_mismatch, expected_data_type: Integer, 
                                          prepend_msg: :input_received, given_data_type: String )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_lessthan_900_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target: {
      priority_4: { respond_within: 900, next_respond_within: 600, resolve_within: 900, business_hours: false, escalation_enabled: true },
      priority_3: { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: true, escalation_enabled: true },
      priority_2: { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: false, escalation_enabled: true },
      priority_1: { respond_within: 3600, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
    }}
    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', 'must be greater than or equal to 900')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_invalid_next_respond_within
    @account.stubs(:next_response_sla_enabled?).returns(true)
    params_hash = create_sla_params_hash_with_company_and_product
    sla_target = { sla_target: {
      priority_4: { respond_within: 900, next_respond_within: 901, resolve_within: 900, business_hours: false, escalation_enabled: true },
      priority_3: { respond_within: 1200, next_respond_within: 1200, resolve_within: 1200, business_hours: true, escalation_enabled: true },
      priority_2: { respond_within: 1800, next_respond_within: 1800, resolve_within: 1800, business_hours: false, escalation_enabled: true },
      priority_1: { respond_within: 3600, next_respond_within: 900, resolve_within: 900, business_hours: false, escalation_enabled: true }
    }}
    params_hash = params_hash.merge(sla_target)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('sla_target[priority_4][next_respond_within]', :Multiple_of_60)])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

# ********************************************************* Escalations for create
 
  def test_create_escalation_with_resolution_only
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge({"escalation":  { "resolution": {"level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                                                                    "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                                                                    "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}}}})
    post :create, construct_params(params_hash)    
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_with_response_only
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge({ "escalation":  { "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] } }})
    post :create, construct_params(params_hash) 
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_with_reminder_response_only
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge({ "escalation":  { "reminder_response": { escalation_time:-3600, agent_ids:[@agent_1.user_id] } }})
    post :create, construct_params(params_hash) 
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_with_reminder_resolution_only
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge({ "escalation":  { "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] } }})
    post :create, construct_params(params_hash) 
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_without_reminder_response_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[escalation_time]", :missing_field )])
  end

  def test_create_escalation_without_reminder_resolution_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[escalation_time]", :missing_field )])
  end

  def test_create_escalation_without_response_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", :missing_field )])
  end

  def test_create_escalation_without_resolution_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", :missing_field )])
  end

  def test_create_escalation_invalid_reminder_response_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
  end

  def test_create_escalation_invalid_reminder_resolution_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
  end

  def test_create_escalation_invalid_response_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 780, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("response[escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_create_escalation_invalid_resolution_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 780, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000' )])
  end

  def test_create_escalation_duplicate_resolution_escalation_time_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 1800, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("resolution[escalation_time]", :duplicate_not_allowed, name: 'escalation time', list: '1800'),
                bad_request_error_pattern("resolution[level_2][escalation_time]", :not_included, list: '3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
  end

  def test_create_escalation_invalid_reminder_response_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[8787] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_create_escalation_invalid_reminder_resolution_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[8787] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_create_escalation_invalid_response_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[8787] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :invalid_list, list: '8787' )])
  end

  def test_create_escalation_invalid_resolution_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[8787]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :invalid_list, list: '8787')])
  end

  def test_create_escalation_without_reminder_response_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600 },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    sla_policy = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern("reminder_response[agent_ids]", :missing_field )])
  end

  def test_create_escalation_without_reminder_resolution_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600 },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    sla_policy = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern("reminder_resolution[agent_ids]", :missing_field )])
  end

  def test_create_escalation_without_response_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0 },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    sla_policy = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern("response[agent_ids]", :missing_field )])
  end

  def test_create_escalation_without_resolution_agent_id_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0 },
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    sla_policy = parse_response @response.body
    assert_response 400
    match_json([bad_request_error_pattern("resolution[level_1][agent_ids]", :missing_field )])
  end

  def test_create_escalation_with_2_resolution_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    sla_policy = parse_response @response.body
    assert_response 201
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_with_5_resolution_sla_policy
    params_hash = create_sla_params_hash_with_company
    get_agents
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]},
                      "level_4": { escalation_time: 28800, agent_ids:[@agent_2.user_id]},
                      "level_5": { escalation_time: 43200, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash) 
    assert_response 400
    match_json([bad_request_error_pattern('level_5', :invalid_field )])
  end

  


  def test_create_sla_policy_with_escalations
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size,11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  end

  def test_create_escalation_next_response_without_feature
    @account.stubs(:next_response_sla_enabled?).returns(false)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('escalation_reminder_next_response', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'reminder_next_response'), 
    bad_request_error_pattern('escalation_next_response', :require_feature_for_attribute, code: :inaccessible_field, feature: :next_response_sla, attribute: 'next_response')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_with_feature
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size, 11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_reminder_next_response_only
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({ "escalation": { "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] } }})
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size, 11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_only
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({ "escalation": { "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] } }})
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size, 11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_reminder_next_response_empty
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({ "escalation": { "reminder_next_response": {} } })
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size, 11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_empty
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({ "escalation": { "next_response": {} } })
    post :create, construct_params(params_hash)
    assert_response 201
    sla_policy = parse_response @response.body
    assert_equal sla_policy.size, 11
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_reminder_next_response_without_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[escalation_time]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_without_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("next_response[escalation_time]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_reminder_next_response_invalid_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[escalation_time]", 
      :not_included, list: '-28800, -14400, -7200, -3600, -1800')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_invalid_escalation_time
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 100, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("next_response[escalation_time]", 
      :not_included, list: '0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800, 259200, 604800, 1209600, 2592000')])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_without_agent_ids
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600 },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_without_agent_ids
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0 },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :missing_field )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_reminder_next_response_invalid_datatype_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:["test"] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_escalation_next_response_invalid_datatype_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:["test"] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :array_datatype_mismatch, expected_data_type: 'Integer' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_reminder_next_response_invalid_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[10001] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("reminder_next_response[agent_ids]", :invalid_list, list: '10001' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_create_escalation_next_response_invalid_agent_id
    @account.stubs(:next_response_sla_enabled?).returns(true)
    get_agents
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge( {"escalation":  {
      "reminder_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_next_response": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "reminder_resolution": { escalation_time: -3600, agent_ids:[@agent_1.user_id] },
      "response": { escalation_time: 0, agent_ids:[@agent_1.user_id] },
      "next_response": { escalation_time: 0, agent_ids:[10001] },
      "resolution": { "level_1": { escalation_time: 0, agent_ids:[@agent_1.user_id]},
                      "level_2": { escalation_time: 1800, agent_ids:[@agent_2.user_id]},
                      "level_3": { escalation_time: 14400, agent_ids:[@agent_2.user_id]}
                    }
      }
    })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern("next_response[agent_ids]", :invalid_list, list: '10001' )])
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

# ********************************************************* Name Description and Active create


  def test_create_with_invalid_name_sla_policy
    post :create, construct_params({name: [12345],applicable_to:{company_ids: [company.id]},sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: String, 
                                          prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_create_description_sla_policy
    agent = get_admin
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({description: "This sla is related to unit test"})
    @controller.stubs(:api_current_user).returns(agent)
    post :create, construct_params(params_hash)
    p "response :: #{response.inspect}"
    assert_response 201
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
    @controller.unstub(:api_current_user)
  end

  def test_create_with_invalid_description_sla_policy
    params_hash = create_sla_params_hash_with_company
    params_hash = params_hash.merge({description: [12,21,212]})
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String,
                                                  prepend_msg: :input_received, given_data_type: Array)])
  end

# ********************************************************* Mixed create

  def test_create_with_invalid_fields_in_conditions_hash
    post :create, construct_params({name: Faker::Lorem.word , applicable_to: { group_id: [1, 2], product_id: [1] },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :invalid_field),
                bad_request_error_pattern('product_id', :invalid_field)])
  end

  def test_create_with_nil_conditions
    post :create, construct_params({})
    assert_response 400
    match_json([bad_request_error_pattern('name', :missing_field,expected_data_type: String),bad_request_error_pattern('sla_target', :missing_field ),
      bad_request_error_pattern('applicable_to', :missing_field,expected_data_type: 'key/value pair')])
  end

  def test_create_with_invalid_fields
    post :create, construct_params({ name: Faker::Lorem.word , conditions: { company_ids: [1] },sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('conditions', :invalid_field)])
  end

  def test_create_with_invalid_data_type
    post :create, construct_params({ name: Faker::Lorem.word , applicable_to: [1, 2],sla_target:create_sla_target})
    assert_response 400
    match_json([bad_request_error_pattern('applicable_to', :datatype_mismatch, expected_data_type: 'key/value pair',
                                                 prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_default_sla_policy
    company = create_company
    default_sla_id = Account.current.sla_policies.find_by_is_default(true).id
    put :update, construct_params({ id: default_sla_id }, applicable_to: { company_ids: [company.id] })
    assert_response 400
    match_json(request_error_pattern('cannot_update_default_sla'))
  end

  def test_escalation_without_sla_mgt_feature
    @account.stubs(:sla_management_enabled?).returns(false)
    get_agents
    params_hash = { name: Faker::Lorem.word, applicable_to: { sources: [2] }, sla_target: create_sla_target }
    params_hash.merge!({ escalation: { response: { escalation_time: 14400, agent_ids: [@agent_1.user_id] } } })
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('escalation', :require_feature_for_attribute, code: :inaccessible_field, feature: :sla_management, attribute: 'escalation')])
    @account.unstub(:sla_management_enabled?)
  end

  def get_agents
    @agent_1 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} ) if @agent_1.nil?
    @agent_2 = add_agent_to_account(@account, {name: Faker::Lorem.word ,active: 1, role: 1} ) if @agent_2.nil?
  end

  # Create SLA policy with invalid name
  def test_create_with_duplicate_name
    @sla_policy = quick_create_sla_policy
    params_hash = { name: @sla_policy.name, applicable_to: { sources: [2] }, sla_target: create_sla_target }
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('name', :duplicate_name_in_sla_policy, code: :invalid_value, policy_name: @sla_policy.name)])
  end

  def test_create_sla_with_valid_custom_source
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:ticket_source_revamp_enabled?).returns(true)
    source_choice = create_custom_source_helper
    account_choice_id = Helpdesk::Source.source_choices(:keys_by_token).select { |ch| ch.reverse![0] == source_choice.account_choice_id }.flatten[0]
    assert_equal source_choice.account_choice_id, account_choice_id
    params_hash = { name: Faker::Lorem.word, applicable_to: { sources: [account_choice_id] }, sla_target: create_sla_target }
    post :create, construct_params(params_hash)
    assert_response 201
    response = parse_response @response.body
    match_json(sla_policy_pattern(Helpdesk::SlaPolicy.last))
    Helpdesk::SlaPolicy.last.delete
  ensure
    Account.any_instance.unstub(:ticket_source_revamp_enabled?)
    source_choice.delete
    Account.unstub(:current)
  end

  def test_create_sla_with_custom_source_wo_feature
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:ticket_source_revamp_enabled?).returns(false)
    source_choice = create_custom_source_helper
    account_choice_id = Helpdesk::Source.source_choices(:token_by_keys).select { |ch| ch == source_choice.account_choice_id }.keys[0]
    assert_nil account_choice_id
    params_hash = { name: Faker::Lorem.word, applicable_to: { sources: [source_choice.account_choice_id] }, sla_target: create_sla_target }
    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
    match_json([bad_request_error_pattern('sources', :invalid_list, list: source_choice.account_choice_id)])
  ensure
    Account.any_instance.unstub(:ticket_source_revamp_enabled?)
    source_choice.delete
    Account.unstub(:current)
  end

  def test_create_sla_with_invalid_custom_source
    params_hash = { name: Faker::Lorem.word, applicable_to: { sources: [125] }, sla_target: create_sla_target }
    post :create, construct_params(params_hash)
    assert_response 400
    response = parse_response @response.body
    match_json([bad_request_error_pattern('sources', :invalid_list, list: '125')])
  end
end
