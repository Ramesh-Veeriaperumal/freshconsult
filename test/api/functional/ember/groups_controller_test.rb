require_relative '../../test_helper'
class Ember::GroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper
  include AgentHelper
  include GroupConstants
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include MemcacheKeys

  def wrap_cname(params)
    { group: params }
  end

  # def test_group_index
  #   3.times do
  #     create_group_private_api(@account)
  #   end
  #   get :index, controller_params(version: 'private')
  #   pattern = []
  #   Account.current.groups.all.each do |group|
  #     pattern << private_group_pattern(group) if group.ticket_assign_type==0
  #     pattern << private_group_pattern_with_ocr(group) if group.ticket_assign_type==10
  #     pattern << private_group_pattern_with_normal_round_robin(group) if group.ticket_assign_type==1 && group.capping_limit==0
  #     pattern << private_group_pattern_with_lbrr(group) if group.ticket_assign_type==1 && group.capping_limit!=0
  #     pattern << private_group_pattern_with_sbrr(group) if group.ticket_assign_type==2
  #   end
  #   assert_response 200
  #   match_json(pattern.ordered!)
  # end

  def enabling_fsm_feature
    Account.current.add_feature(:field_service_management)
  end

  def revoke_fsm_feature
    Account.current.revoke_feature(:field_service_management)
  end

  def test_show_group
    group = create_group_private_api(@account)
    get :show, controller_params(version: 'private', id: group.id)
    assert_response 200
    match_json(private_group_pattern(Group.find(group.id)))
  end

  def test_show_group_with_contribution_agents
    group = create_group_with_agents(@account)
    agent = add_agent_to_account(@account, active: true)
    agent.build_agent_groups_attributes([], [group.id])
    agent.save
    get :show, controller_params(version: 'private', id: group.id)
    assert_response 200
    match_json(private_group_pattern(Group.find(group.id)))
  end

  def test_show_group_without_manage_availability_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)   
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      round_robin_type: 1,
      allow_agents_to_change_availability:true,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for:'30m'
    })      
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
  end
  
  def test_create_group_with_existing_name
    existing_group = Group.first || create_group(@account)
    post :create, construct_params({version: 'private'}, name: existing_group.name, description: Faker::Lorem.paragraph,assignment_type: 0)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['group_id'], existing_group.id
    match_json([bad_request_error_pattern_with_additional_info('name', additional_info, :'has already been taken')])
  end

  def test_create_group_with_no_assignment    
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 0,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for: '30m'
    })
    assert_response 201
    match_json(private_group_pattern(Group.last))
  end  

  def test_create_group_with_group_type_valid
    enabling_fsm_feature
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 0,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for: '30m',
      group_type: SUPPORT_GROUP_NAME
    })
    assert_response 201
    match_json(private_group_pattern(Group.last))
  ensure
    revoke_fsm_feature
  end

  def test_create_group_with_group_type_invalid
    enabling_fsm_feature
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 0,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for: '30m',
      group_type: Faker::Lorem.characters(10)
    })
    assert_response 400
    res = JSON.parse response.body
    assert_equal res["errors"][0]["code"],"invalid_value"
  ensure
    revoke_fsm_feature
  end 

  def test_create_group_with_ocr  
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)    
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 2,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for:'30m',
      allow_agents_to_change_availability:true
    })
    assert_response 201
    match_json(private_group_pattern_with_ocr(Group.last))
    Account.current.stubs(:features?).with(:round_robin).returns(false) 
    Account.current.unstub(:omni_channel_routing_enabled?)
  end

  def test_create_field_group_with_support_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 0,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for: '30m',
      group_type: FIELD_GROUP_NAME
    })
    assert_response 201
    match_json(private_group_pattern(Group.last))
  ensure
    destroy_field_group
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_create_support_group_with_field_agent
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_agent_type
    agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    post :create, construct_params({ version: 'private' }, {
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 0,
      business_hour_id: 1,
      escalate_to: 1,
      agent_ids: [agent.id],
      unassigned_for: '30m',
      group_type: SUPPORT_GROUP_NAME
    })
    assert_response 400
    match_json([bad_request_error_pattern('agent_ids', :should_not_be_field_agent)])
  ensure
    agent.destroy
    destroy_field_agent
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_create_field_group_with_assignment_type_invalid
    enabling_fsm_feature
    create_field_group_type
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      business_hour_id:1,
      escalate_to:1,
      unassigned_for: '30m',
      group_type: FIELD_GROUP_NAME
    })
    assert_response 400
    res = JSON.parse response.body
    assert_equal res["errors"][0]["code"],"invalid_value"
  ensure
    destroy_field_group
    revoke_fsm_feature
  end

  def test_create_group_with_normal_round_robin
    Account.current.stubs(:features?).with(:round_robin).returns(true)        
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      round_robin_type: 1,
      allow_agents_to_change_availability:true,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for:'30m'
    })
    assert_response 201
    match_json(private_group_pattern_with_normal_round_robin(Group.last))
    Account.current.stubs(:features?).with(:round_robin).returns(false)   
  end

  def test_create_group_with_lbrr   
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    Account.current.stubs(:round_robin_capping_enabled?).returns(true)
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      round_robin_type:2,
      capping_limit:5,
      allow_agents_to_change_availability:true,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for:'30m'
    })
    assert_response 201
    match_json(private_group_pattern_with_lbrr(Group.last))
    Account.current.stubs(:features?).with(:round_robin).returns(false)
    Account.current.unstub(:round_robin_capping_enabled?)
  end

  def test_create_group_with_sbrr  
    Account.current.stubs(:features?).with(:round_robin).returns(true) 
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      round_robin_type:3,
      capping_limit:5,
      allow_agents_to_change_availability:true,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for: '30m'
    })
    assert_response 201
    match_json(private_group_pattern_with_sbrr(Group.last))
    Account.current.stubs(:features?).with(:round_robin).returns(false)
    Account.current.unstub(:skill_based_round_robin_enabled?)
  end  

  def test_create_group_with_lbrr_by_omniroute
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)    
    Account.current.stubs(:lbrr_by_omniroute_enabled?).returns(true)    
    post :create, construct_params({version: 'private'},{
      name: Faker::Lorem.characters(10),
      description: Faker::Lorem.paragraph,
      assignment_type: 1,
      round_robin_type: 12,
      business_hour_id:1,
      escalate_to:1,
      agent_ids:[1],
      unassigned_for:'30m',
      allow_agents_to_change_availability:true
    })
    assert_response 201
    match_json(private_group_pattern_with_lbrr_by_omniroute(Group.last))
  ensure
    Account.current.unstub(:features?)
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:lbrr_by_omniroute_enabled?)
  end
  
  def test_update_group
    group = create_group_private_api(@account)
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for: '30m', agent_ids: [1])
    assert_response 200
    match_json(private_group_pattern(Group.find_by_id(group.id)))
  end

  def test_update_group_type
    enabling_fsm_feature
    Account.stubs(:current).returns(@account)
    create_field_group_type
    group = create_group_private_api(@account)
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for: '30m', agent_ids: [1], group_type: FIELD_GROUP_NAME)
    assert_response 400
    res = JSON.parse response.body
    assert_equal res["errors"][0]["message"],"Unexpected/invalid field in request"
  ensure
    destroy_field_group
    revoke_fsm_feature
    Account.unstub(:current)
  end

  def test_update_group_from_noass_to_lbrr
    @account.add_feature :round_robin
    group = create_group_private_api(@account)
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for: '30m', agent_ids:[1],
    assignment_type: 1, round_robin_type: 2, capping_limit: 23 )
    assert_response 200
    match_json(private_group_pattern_with_lbrr(Group.find_by_id(group.id)))
  ensure
    @account.revoke_feature :round_robin
  end

  def test_update_group_from_lbrr_to_noass
    @account.add_feature :round_robin
    group = create_group_private_api(@account, ticket_assign_type:1, capping_limit: 23)
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for:'30m', agent_ids:[1],
    assignment_type: 0)
    assert_response 200
    match_json(private_group_pattern(Group.find_by_id(group.id)))
  ensure
    @account.revoke_feature :round_robin
  end

  def test_update_group_from_sbrr_to_normal_round_robin
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    group = create_group_private_api(@account, ticket_assign_type:2, capping_limit:23) 
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for:'30m', agent_ids:[1],
    round_robin_type:1)
    assert_response 200
    match_json(private_group_pattern_with_normal_round_robin(Group.find_by_id(group.id)))
    Account.current.stubs(:features?).with(:round_robin).returns(false)
  end

  def test_update_group_from_lbrr_to_normal_round_robin
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    group = create_group_private_api(@account, ticket_assign_type:1, capping_limit:23) 
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for:'30m', agent_ids:[1],
    round_robin_type:1)
    assert_response 200
    match_json(private_group_pattern_with_normal_round_robin(Group.find_by_id(group.id)))
    Account.current.stubs(:features?).with(:round_robin).returns(false)
  end

  def test_update_group_from_sbrr_to_lbrr_by_omniroute
    @account.add_feature :round_robin
    @account.add_feature(:omni_channel_routing)
    @account.add_feature(:lbrr_by_omniroute) 
    group = create_group_private_api(@account, ticket_assign_type:2, capping_limit:23) 
    put :update, construct_params({version:'private', id: group.id }, escalate_to: 1, unassigned_for:'30m', agent_ids:[1],
    round_robin_type: 12)
    assert_response 200
    match_json(private_group_pattern_with_lbrr_by_omniroute(Group.find_by_id(group.id)))
  ensure
    @account.revoke_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.revoke_feature :round_robin
  end

  def test_update_group_from_lbrr_to_ocr
    Account.current.stubs(:features?).with(:round_robin).returns(true)
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true) 
    group = create_group_private_api(@account, ticket_assign_type:1,capping_limit:23)    
    put :update, construct_params({version:'private', id: group.id },escalate_to: 1, unassigned_for:'30m', agent_ids:[1], assignment_type:2)
    assert_response 200
    match_json(private_group_pattern_with_ocr(Group.find_by_id(group.id)))
    Account.current.stubs(:features?).with(:round_robin).returns(false) 
    Account.current.unstub(:omni_channel_routing_enabled?)
  end 

  def test_delete_group
    group = create_group_private_api(@account, ticket_assign_type:2, capping_limit:23) 
    delete :destroy, construct_params(id: group.id)
    assert_equal ' ', 	@response.body
    assert_response 204
    assert_nil Group.find_by_id(group.id)
  end

  def test_supervisor_index
    User.stubs(:current).returns(User.first)
    User.current.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.current.stubs(:privilege?).with(:manage_availability).returns(true)   
    Account.current.groups.delete_all
    3.times do
      create_group_private_api(@account, agent_ids:[User.first.id])
    end
    pattern = []
    User.current.groups.order(:name).all.each do |group|
      pattern << private_group_pattern_index(group)
    end
    get :index, controller_params(version: 'private')
  
    assert_response 200
    match_json(pattern.ordered!)
  ensure
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
  end

  def test_get_support_agent_groups
    get :index, controller_params(version: 'private', group_type: GroupConstants::SUPPORT_GROUP_NAME)
    assert_response 200
  end

  def test_get_support_agent_groups_with_pagination
    get :index, controller_params(version: 'private', group_type: GroupConstants::SUPPORT_GROUP_NAME, page: 1, per_page: 5)
    assert_response 200
  end

  def test_get_field_agent_groups
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    get :index, controller_params(version: 'private', group_type: GroupConstants::FIELD_GROUP_NAME)
    assert_response 200
  end

  def test_get_field_agent_groups_with_pagination
    Account.stubs(:current).returns(Account.first)
    enabling_fsm_feature
    create_field_group_type
    get :index, controller_params(version: 'private', group_type: GroupConstants::FIELD_GROUP_NAME, page: 1, per_page: 5)
    assert_response 200
  end

  def test_index_with_per_page_greater_than_limit
    get :index, controller_params(version: 'private', per_page: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 4)
    assert_response 400
  end

  def test_group_with_agent_availability_with_agent_statuses_with_round_robin
    @account.launch :agent_statuses
    @account.add_feature :round_robin
    post :create, construct_params(version: 'private', name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   business_hour_id: 1,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true,
                                   assignment_type: 1)
    assert_response 201
    match_json(private_group_pattern_with_normal_round_robin(Group.last))
  ensure
    @account.rollback :agent_statuses
    @account.revoke_feature :round_robin
  end

  def test_group_with_agent_availability_with_agent_statuses_with_sbrr
    @account.launch :agent_statuses
    @account.add_feature :round_robin
    @account.add_feature :skill_based_round_robin
    post :create, construct_params(version: 'private', name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   business_hour_id: 1,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true,
                                   assignment_type: 1,
                                   round_robin_type: 3,
                                   capping_limit: 5)
    assert_response 201
    match_json(private_group_pattern_with_sbrr(Group.last))
  ensure
    @account.rollback :agent_statuses
    @account.revoke_feature :round_robin
    @account.revoke_feature :skill_based_round_robin
  end

  def test_group_with_agent_availability_with_agent_statuses_without_round_robin
    @account.launch :agent_statuses
    @account.revoke_feature :round_robin
    post :create, construct_params(version: 'private', name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   business_hour_id: 1,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true)
    assert_response 201
    pattern = private_group_pattern(Group.last).merge(allow_agents_to_change_availability: true)
    match_json(pattern)
  ensure
    @account.rollback :agent_statuses
    @account.add_feature :round_robin
  end

  def test_group_with_agent_availability_without_agent_statuses
    @account.rollback :agent_statuses
    post :create, construct_params(version: 'private', name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   business_hour_id: 1,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  end

  def test_group_with_agent_availability_with_agent_statues_with_field_agent
    @account.launch :agent_statuses
    @account.revoke_feature :round_robin
    @account.revoke_feature :omni_channel_routing
    enabling_fsm_feature
    create_field_group_type
    post :create, construct_params(version: 'private', name: Faker::Lorem.characters(10),
                                   description: Faker::Lorem.paragraph,
                                   business_hour_id: 1,
                                   escalate_to: 1,
                                   agent_ids: [1],
                                   unassigned_for: '30m',
                                   allow_agents_to_change_availability: true,
                                   group_type: GroupConstants::FIELD_GROUP_NAME)
    assert_response 400
    match_json([bad_request_error_pattern('allow_agents_to_change_availability', :invalid_field)])
  ensure
    destroy_field_group
    revoke_fsm_feature
    @account.rollback :agent_statuses
  end
end
