# frozen_string_literal: true

require_relative '../../test_helper.rb'
require Rails.root.join('test/api/helpers/test_case_methods')
require 'webmock/minitest'
require 'faker'

module Admin
  class GroupsControllerTest < ActionController::TestCase
    include GroupsTestHelper
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
    include PrivilegesHelper

    def wrap_cname(params)
      { group: params }
    end

    def setup
      super
      create_test_account if Account.first.nil?
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      Account.current.launch :group_management_v2
      User.stubs(:current).returns(User.first)
    end

    def teardown
      Account.unstub(:current)
      Account.current.rollback :group_management_v2
      User.unstub(:current)
      super
    end

    # index tests

    def test_index_supervisor_valid
      User.current.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.current.stubs(:privilege?).with(:manage_availability).returns(true)

      Account.current.groups.delete_all
      group_ids = create_support_agent_groups(3)

      pattern = []
      Account.current.groups.order(:name).all.each do |group|
        pattern << group_management_v2_pattern(group)
      end

      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(pattern.ordered!)
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
      User.any_instance.unstub(:privilege?)
    end

    def test_get_support_agent_groups
      group_ids = create_support_agent_groups(3)
      pattern = []
      Account.current.groups.order(:name).all.each do |group|
        pattern << group_management_v2_pattern(group)
      end

      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME)
      assert_response 200
      match_json(pattern.ordered!)
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
    end

    def test_get_support_agent_groups_with_pagination
      group_ids = create_support_agent_groups(3)
      pattern = []
      Account.current.groups.order(:name).all.each do |group|
        pattern << group_management_v2_pattern(group)
      end

      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      match_json(pattern.ordered!)
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
    end

    def test_get_support_agent_groups_invalid
      get :index, controller_params(version: 'private', group_type: GroupConstants::SUPPORT_GROUP_NAME)
      assert_response 400
      result = (JSON.parse response.body)['errors'][0]['code']
      assert_equal(result, 'invalid_field')
    end

    def test_get_field_agent_groups
      Account.current.add_feature(:field_service_management)
      create_field_group_type

      group_id = create_group(Account.current, agent_ids: [Account.current.agents.first.user_id], group_type: GroupConstants::FIELD_GROUP_NAME).id

      pattern = []
      Account.current.groups.field_agent_groups.order(:name).all.each do |group|
        pattern << group_management_v2_pattern(group)
      end

      get :index, controller_params(version: 'private', type: GroupConstants::FIELD_GROUP_NAME)

      assert_response 200
      match_json(pattern.ordered!)
    ensure
      Account.current.groups.where(id: group_id).destroy_all
      Account.current.revoke_feature(:field_service_management)
    end

    def test_get_field_agent_groups_with_pagination
      Account.current.add_feature(:field_service_management)
      create_field_group_type

      10.times { create_group(Account.current, group_type: 2) }

      get :index, controller_params(version: 'private', type: GroupConstants::FIELD_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      assert_equal((JSON.parse response.body).count, 5)
      assert_include response.header['Link'], 'api/_/admin/groups?type=field_agent_group&page=2&per_page=5'

      get :index, controller_params(version: 'private', type: GroupConstants::FIELD_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      assert_equal((JSON.parse response.body).count, 5)
    ensure
      Account.current.revoke_feature(:field_service_management)
      Account.current.groups.delete_all
    end

    def test_index_with_per_page_greater_than_limit
      group_ids = create_support_agent_groups(1)

      get :index, controller_params(version: 'private', per_page: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 4)
      assert_response 400
      match_json(description: 'Validation failed', errors: [{ field: 'per_page', message: 'It should be a Positive Integer less than or equal to 100', code: 'invalid_value' }])
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
    end

    def test_get_field_agent_group_with_pagination
      Account.current.add_feature(:field_service_management)
      create_field_group_type
      6.times { create_group(Account.current, group_type: 2) }
      get :index, controller_params(version: 'private', type: GroupConstants::FIELD_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      assert_equal((JSON.parse response.body).count, 5)
      assert_include response.header['Link'], 'api/_/admin/groups?type=field_agent_group&page=2&per_page=5'

      get :index, controller_params(version: 'private', type: GroupConstants::FIELD_GROUP_NAME, page: 2, per_page: 5)
      assert_equal((JSON.parse response.body).count, 1)
      assert_response 200
    ensure
      Account.current.revoke_feature(:field_service_management)
    end

    def test_index_validate_paginations
      group_ids = create_support_agent_groups(10)
      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      assert_equal((JSON.parse response.body).count, 5)
      assert_include response.header['Link'], 'api/_/admin/groups?type=support_agent_group&page=2&per_page=5'

      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME, page: 2, per_page: 5)
      assert_equal((JSON.parse response.body).count, 5)
      assert_response 200
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
    end

    def test_index_with_omni_channel_groups
      Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
      Account.any_instance.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
      Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
      ApiGroupsController.any_instance.stubs(:request_ocr).returns(omni_channel_groups_response)
      get :index, controller_params(include: 'omni_channel_groups', auto_assignment: true)
      assert_response 200
      pattern = []
      Account.current.groups.round_robin_groups.order(:name).each do |group|
        pattern << group_management_v2_pattern(Group.find(group.id))
      end
      omni_channel_groups_response['ocr_groups'].each do |channel_group|
        omni_channel_group = omni_channel_groups_pattern(channel_group)
        pattern << omni_channel_group if omni_channel_group.present?
      end
      match_json(pattern)
    ensure
      ApiGroupsController.any_instance.unstub(:request_ocr)
      Account.any_instance.unstub(:features?)
      Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
      Account.any_instance.unstub(:omni_channel_routing_enabled?)
      Account.unstub(:current)
    end

    ##

    # show tests

    def test_show_group_valid
      group = create_group(Account.current, agent_ids: [Account.current.agents.first.user_id])
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    # tests for all assignment_type

    def test_no_assignment_type
      group = create_group(Account.current, ticket_assign_type: 0)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_round_robin_assignment_type
      group = create_group(Account.current, ticket_assign_type: 1, agent_ids: [Account.current.agents.first.user_id])
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_rr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_lbrr_assignment_type
      group = create_group(Account.current, ticket_assign_type: 1, capping_limit: 2)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_lbrr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_sbrr_assignment_type
      group = create_group(Account.current, ticket_assign_type: 2, capping_limit: 2, agent_ids: [Account.current.agents.first.user_id])
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_sbrr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_lbrr_by_onmiroute_type
      group = create_group(Account.current, ticket_assign_type: 12)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_lbrr_by_omni_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_invalid_group_id_show
      get :show, controller_params(version: 'private', id: 199_991)
      assert_response 404
    end

    # CREATE tests

    def test_create_support_group_with_field_agent
      Account.current.add_feature(:field_service_management)
      create_field_agent_type
      agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id,
                                              agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT),
                                              ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      post :create, construct_params({ version: 'private' },
                                     name: 'this is test name',
                                     description: Faker::Lorem.paragraph,
                                     type: SUPPORT_GROUP_NAME,
                                     agent_ids: [agent.id],
                                     unassigned_for: '30m')
      assert_response 400
      match_json([bad_request_error_pattern('agent_ids', :should_not_be_field_agent)])
    ensure
      agent.destroy
      destroy_field_agent
      Account.current.revoke_feature(:field_service_management)
    end

    def test_create_group_with_group_type_invalid
      Account.current.add_feature(:field_service_management)
      post :create, construct_params({ version: 'private' },
                                     name: 'test the name', description: Faker::Lorem.paragraph, type: Faker::Lorem.characters(10))
      assert_response 400
      res = JSON.parse response.body
      assert_equal res['errors'][0]['code'], 'invalid_value'
    ensure
      Account.current.revoke_feature(:field_service_management)
    end

    def test_create_group_with_existing_name
      existing_group = Group.first || create_group(@account)
      post :create, construct_params({ version: 'private' }, name: existing_group.name, description: Faker::Lorem.paragraph, type: 'support_agent_group')
      assert_response 400
      match_json([bad_request_error_pattern('name', nil, name: existing_group.name, prepend_msg: :duplicate_group_name)])
    end

    def test_create_group_without_manage_availability_privilege
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)

      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.agents.first.user_id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      post :create, construct_params({ version: 'private' }, group_params)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_create_no_valid
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      post :create, construct_params({ version: 'private' }, group_params)
      assert_response 201
      parsed_response = JSON.parse(response.body)
      group_id = parsed_response['id']
      match_json(group_management_v2_pattern(Group.find(group_id)))
    ensure
      Account.current.groups.find_by_id(group_id).destroy
    end

    def test_create_group_search_publish_event
      RabbitmqWorker.clear
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: 1,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      post :create, construct_params({ version: 'private' }, group_params)
      assert_equal RabbitmqWorker.jobs.size, 1
      assert_equal RabbitmqWorker.jobs[0]['args'][0], 'users'
      assert_equal JSON.parse(RabbitmqWorker.jobs[0]['args'][1])['user_properties']['id'], Account.current.agents.first.user_id
    end

    # create all assignment_type settings groups
    ASSIGNMENT_SETTINGS.each_pair do |assignment_type, assignment_payload|
      capping_limit = %i[load_based_round_robin skill_based_round_robin].include?(assignment_type)
      define_method "test_create_#{assignment_type}_valid" do
        groups_assignment_type_stubs(assignment_type) do
          group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                           type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
          group_params.merge!(assignment_payload)

          group_params[:automatic_agent_assignment][:settings][0][:assignment_type_settings][:capping_limit] = 2 if capping_limit

          post :create, construct_params({ version: 'private' }, group_params)
          parsed_response = JSON.parse(response.body)
          group_id = parsed_response['id']
          assert_response(201)
          pattern = safe_send("group_management_#{METHOD_NAME_MAPPINGS[assignment_type]}_pattern", Group.find(group_id))
          match_json(pattern)
          Account.current.groups.find_by_id(group_id).destroy
        end
      end
    end

    # UPDATE tests starts

    def test_update_name_valid
      Account.current.add_feature :round_robin
      existing_group = create_group(@account)
      name = "random #{Faker::Lorem.characters(7)} 007"
      put :update, construct_params({ version: 'private', id: existing_group.id }, name: name)
      assert_response 200
      parsed_response = JSON.parse(response.body)
      group_name = parsed_response['name']
      assert_equal name, group_name
      existing_group.reload
      match_json(group_management_v2_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      existing_group.destroy
    end

    def test_update_business_calendar_id_valid
      existing_group = create_group(@account)
      business_calendar_id = @account.business_calendar.first.id
      put :update, construct_params({ version: 'private', id: existing_group.id }, business_calendar_id: business_calendar_id)
      assert_response 200
      parsed_response = JSON.parse(response.body)
      group_business_calendar_id = parsed_response['business_calendar_id']
      assert_equal business_calendar_id, group_business_calendar_id
      existing_group.reload
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    def test_update_agent_ids_valid
      existing_group = create_group(@account)
      agent_ids = [@account.account_managers.first.id]
      put :update, construct_params({ version: 'private', id: existing_group.id }, agent_ids: agent_ids)
      assert_response 200
      parsed_response = JSON.parse(response.body)
      group_agent_ids = parsed_response['agent_ids']
      assert_equal agent_ids, group_agent_ids
      existing_group.reload
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    def test_update_unassigned_for_valid
      existing_group = create_group(@account)
      unassigned_for = '30m'
      put :update, construct_params({ version: 'private', id: existing_group.id }, unassigned_for: unassigned_for)
      assert_response 200
      parsed_response = JSON.parse(response.body)
      group_unassigned_for = parsed_response['unassigned_for']
      assert_equal unassigned_for, group_unassigned_for
      existing_group.reload
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    def test_update_escalate_to_valid
      existing_group = create_group(@account)
      escalate_to = @account.account_managers.first.id
      put :update, construct_params({ version: 'private', id: existing_group.id }, escalate_to: escalate_to)
      assert_response 200
      parsed_response = JSON.parse(response.body)
      group_escalate_to = parsed_response['escalate_to']
      assert_equal escalate_to, group_escalate_to
      existing_group.reload
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    # assignment_type tests

    def test_update_no_assignment_valid
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:no_assignment])
      assert_response 200
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    def test_update_group_with_existing_group_name_for_same_group
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, name: existing_group.name)
      assert_response 200
      match_json(group_management_v2_pattern(existing_group))
    ensure
      existing_group.destroy
    end

    def test_update_group_with_existing_group_name_for_different_group
      group1 = create_group(@account)
      group2 = create_group(@account)
      put :update, construct_params({ version: 'private', id: group1.id }, name: group2.name)
      assert_response 400
      match_json([bad_request_error_pattern('name', nil, name: group2.name, prepend_msg: :duplicate_group_name)])
    ensure
      group1.destroy
      group2.destroy
    end

    def test_update_omni_channel_routing_valid
      Account.current.add_feature :omni_channel_routing
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:omni_channel_routing])
      assert_response 200
      existing_group.reload
      match_json(group_management_ocr_pattern(existing_group))
    ensure
      Account.current.add_feature :omni_channel_routing
      existing_group.destroy
    end

    def test_update_round_robin_valid
      Account.current.add_feature :round_robin
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:round_robin])
      assert_response 200
      existing_group.reload
      match_json(group_management_rr_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      existing_group.destroy
    end

    def test_update_load_based_round_robin_valid
      Account.current.add_feature :round_robin
      Account.current.add_feature :round_robin_load_balancing
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, automatic_agent_assignment: lbrr_params[:automatic_agent_assignment])
      p JSON.parse(response.body)
      assert_response 200
      match_json(group_management_lbrr_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :round_robin_load_balancing
      existing_group.destroy
    end

    def test_update_skill_based_round_robin_valid
      Account.current.add_feature :round_robin
      Account.current.add_feature :skill_based_round_robin
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, automatic_agent_assignment: sbrr_params[:automatic_agent_assignment])
      p JSON.parse(response.body)
      assert_response 200
      match_json(group_management_sbrr_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :skill_based_round_robin
      existing_group.destroy
    end

    def test_update_lbrr_by_omniroute_valid
      Account.current.add_feature :round_robin
      Account.current.add_feature :lbrr_by_omniroute
      Account.current.add_feature :omni_channel_routing
      existing_group = create_group(@account)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:lbrr_by_omniroute])
      p JSON.parse(response.body)
      assert_response 200
      existing_group.reload
      match_json(group_management_v2_lbrr_by_omni_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :lbrr_by_omniroute
      Account.current.revoke_feature :omni_channel_routing
      existing_group.destroy
    end

    def test_update_ocr_and_lbrr_feature_valid
      Account.current.add_feature :round_robin
      Account.current.add_feature :skill_based_round_robin
      Account.current.add_feature :lbrr_by_omniroute
      Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)

      existing_group = create_group(Account.current, ticket_assign_type: 3, capping_limit: 2)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:lbrr_by_omniroute])
      assert_response 200
      existing_group.reload
      match_json(group_management_v2_lbrr_by_omni_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :skill_based_round_robin
      Account.current.revoke_feature :lbrr_by_omniroute
      Account.any_instance.unstub(:omni_channel_routing_enabled?)
      existing_group.destroy
    end

    def test_update_ocr_and_lbrr_feature_invalid
      Account.current.add_feature :round_robin
      Account.current.add_feature :skill_based_round_robin
      Account.current.add_feature :lbrr_by_omniroute
      Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(false)

      existing_group = create_group(Account.current, ticket_assign_type: 3, capping_limit: 2)
      put :update, construct_params({ version: 'private', id: existing_group.id }, ASSIGNMENT_SETTINGS[:lbrr_by_omniroute])
      assert_response 400
      match_json([bad_request_error_pattern('automatic_agent_assignment[:settings][:assignment_type]', :require_feature, feature: 'omni_channel_routing'.titleize, code: :require_feature)])
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :skill_based_round_robin
      Account.current.revoke_feature :lbrr_by_omniroute
      Account.any_instance.unstub(:omni_channel_routing_enabled?)
      existing_group.destroy
    end

    def test_update_ocr_and_lbrr_feature_invalid_with_round_robin_and_assigment_type_error
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :skill_based_round_robin

      existing_group = create_group(Account.current, ticket_assign_type: 2, capping_limit: 2)
      put :update, construct_params({ version: 'private', id: existing_group.id }, automatic_agent_assignment: sbrr_params[:automatic_agent_assignment])
      assert_response 400
      match_json([bad_request_error_pattern('round_robin_type', :require_feature, feature: 'skill_based_round_robin'.titleize, code: :require_feature),
                  bad_request_error_pattern('automatic_agent_assignment[:settings][:assignment_type]', :require_feature, feature: 'round_robin'.titleize, code: :require_feature)])
    ensure
      existing_group.destroy
    end

    def test_update_support_group_with_field_agent
      Account.current.add_feature(:field_service_management)
      create_field_agent_type
      group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      put :update, construct_params({ id: group.id }, agent_ids: [agent.id])
      assert_response 400
      match_json([bad_request_error_pattern('agent_ids', :should_not_be_field_agent)])
    ensure
      agent.destroy
      destroy_field_agent
      Account.current.revoke_feature(:field_service_management)
    end

    def test_update_group_type_of_group
      group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
      put :update, construct_params({ id: group.id }, type: GroupConstants::SUPPORT_GROUP_NAME)
      assert_response 400
      match_json([bad_request_error_pattern('type', :invalid_field)])
    ensure
      group.destroy
    end

    def test_update_group_with_invalid_id
      put :update, construct_params({ id: Random.rand(999..1007) }, description: Faker::Lorem.paragraph)
      assert_response 404
      assert_equal ' ', @response.body
      assert_response :missing
    end

    def test_update_group_with_deleted_or_invalid_agent_id
      agent_id = Faker::Number.between(5000, 10_000)
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      put :update, construct_params({ id: group.id }, agent_ids: [agent_id])
      assert_response 400
      match_json([bad_request_error_pattern('agent_ids', :invalid_list, list: agent_id.to_s)])
    ensure
      group.destroy
    end

    def test_update_group_add_agent_search_publish_event
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      agent_type_id = Account.current.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
      user = add_test_agent(Account.current, agent_type: agent_type_id)
      RabbitmqWorker.clear
      put :update, construct_params({ version: 'private', id: group.id }, agent_ids: [user.id])
      assert_equal RabbitmqWorker.jobs.size, 2
      assert_equal RabbitmqWorker.jobs[1]['args'][0], 'users'
      assert_equal JSON.parse(RabbitmqWorker.jobs[1]['args'][1])['user_properties']['id'], user.id
    end

    def test_update_group_add_agent_with_worker_execution
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      agent_type_id = Account.current.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
      user = add_test_agent(Account.current, agent_type: agent_type_id)
      RabbitmqWorker.clear
      Sidekiq::Testing.inline! { put :update, construct_params({ version: 'private', id: group.id }, agent_ids: [user.id]) }
      assert_equal RabbitmqWorker.jobs.size, 0
    end

    def test_update_group_with_invalid_field_values
      Account.current.add_feature :round_robin
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      put :update, construct_params({ id: group.id }, escalate_to: Faker::Lorem.characters(5),
                                                      unassigned_for: Faker::Lorem.characters(5),
                                                      name: Faker::Lorem.characters(300), description: Faker::Lorem.paragraph)
      assert_response 400
      match_json([bad_request_error_pattern('escalate_to', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                  bad_request_error_pattern('unassigned_for', :not_included, list: '30m,1h,2h,4h,8h,12h,1d,2d,3d'),
                  bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters')])
    ensure
      Account.current.revoke_feature :round_robin
      group.destroy
    end

    def test_update_group_with_blank_name
      Account.current.add_feature :round_robin
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      put :update, construct_params({ id: group.id }, name: '')
      assert_response 400
      match_json([bad_request_error_pattern('name', :blank)])
    ensure
      Account.current.revoke_feature :round_robin
      group.destroy
    end

    def test_update_group_name_as_supervisor
      group = create_group(@account, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph, ticket_assign_type: 1)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
      put :update, construct_params({ id: group.id }, name: "test", description: "change description")
      assert_response 403
    ensure
      group.destroy
    end

    def test_update_load_based_round_robin_valid_as_supervisor
      Account.current.add_feature :round_robin
      Account.current.add_feature :round_robin_load_balancing
      existing_group = create_group(@account)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_availability).returns(true)
      put :update, construct_params({ version: 'private', id: existing_group.id }, automatic_agent_assignment: lbrr_params[:automatic_agent_assignment])
      assert_response 200
      match_json(group_management_lbrr_pattern(existing_group))
    ensure
      Account.current.revoke_feature :round_robin
      Account.current.revoke_feature :round_robin_load_balancing
      existing_group.destroy
    end

    def test_update_group_type_invalid
      Account.current.add_feature(:field_service_management)
      create_field_group_type
      group = create_group(@account)
      put :update, construct_params({ version: 'private', id: group.id },
                                    escalate_to: Account.current.account_managers.first.id, unassigned_for: '30m', agent_ids: [Account.current.agents.first.user_id], type: FIELD_GROUP_NAME)
      assert_response 400
      match_json([bad_request_error_pattern('type', :invalid_field)])
    ensure
      destroy_field_group
      Account.current.revoke_feature(:field_service_management)
      group.destroy
    end

    ##

    # Public API test

    def test_create_no_valid_public
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      post :create, construct_params({}, group_params)
      assert_response 201
      parsed_response = JSON.parse(response.body)
      group_id = parsed_response['id']
      match_json(group_management_v2_pattern(Group.find(group_id)))
    ensure
      Account.current.groups.find_by_id(group_id).destroy
    end

    def test_update_lbrr_by_omniroute_feature
      Account.any_instance.stubs(:lbrr_by_omniroute_enabled?).returns(true)
      Account.current.add_feature(:round_robin)
      group = create_group(Account.current, name: Faker::Lorem.characters(7), description: Faker::Lorem.paragraph)
      put :update, construct_params({ id: group.id }, automatic_agent_assignment: lbrr_params[:automatic_agent_assignment])
      assert_response 400
    ensure
      Account.current.revoke_feature(:round_robin)
      Account.any_instance.unstub(:lbrr_by_omniroute_enabled?)
    end

    # DELETE tests

    def test_delete_group_with_invalid_id
      delete :destroy, construct_params(id: Random.rand(1000..1010))
      assert_response 404
      assert_equal ' ', @response.body
    end

    def test_delete_group
      group = create_group(@account, ticket_assign_type: 2, capping_limit: 23)
      delete :destroy, construct_params(id: group.id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil Group.find_by_id(group.id)
    end

    def test_delete_group_without_privilege
      group = create_group(@account, ticket_assign_type: 2, capping_limit: 23)
      remove_privilege(@agent, :manage_account)
      remove_privilege(@agent, :admin_tasks)
      delete :destroy, construct_params(id: group.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      add_privilege(@agent, :manage_account)
      add_privilege(@agent, :admin_tasks)
    end

    # create omni group tests

    def test_create_omni_group_invalid
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      Freshid::V2::Models::Usergroup.stubs(:create).returns(nil)
      post :create, construct_params({ version: 'private' }, group_params)
      assert_response 400
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)
    end

    def test_create_omni_group_valid
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])

      freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
      Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)
      post :create, construct_params({ version: 'private' }, group_params)
      assert_response 201
      group_id = JSON.parse(response.body)['id']
      match_json(group_management_v2_pattern(Group.find(group_id)))
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)

      Account.current.groups.find_by_id(group_id).destroy
    end

    # create all assignment_type settings groups
    OMNI_ASSIGNMENT_SETTINGS.each_pair do |assignment_type, assignment_payload|
      capping_limit = %i[load_based_round_robin skill_based_round_robin].include?(assignment_type)
      define_method "test_create_omni_group_with_#{assignment_type}_valid" do
        omni_group_stub
        group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                         type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
        group_params.merge!(assignment_payload)

        capping_limit_param = assignment_type == :load_based_round_robin ? lbrr_params : sbrr_params
        capping_limit_param[:automatic_agent_assignment][:settings].push chat_params
        Account.any_instance.stubs(:lbrr_by_omniroute_enabled?).returns(false) if assignment_type == :load_based_round_robin

        group_params[:automatic_agent_assignment][:settings][0][:assignment_type_settings][:capping_limit] = 2 if capping_limit
        freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
        Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)
        groups_assignment_type_stubs(assignment_type.to_sym) do
          post :create, construct_params({ version: 'private' }, group_params)
        end
        group_id = JSON.parse(response.body)['id']
        assert_response 201
        pattern = safe_send("group_management_#{METHOD_NAME_MAPPINGS[assignment_type]}_pattern", Group.find(group_id))
        match_json(pattern)
        Account.any_instance.unstub(:lbrr_by_omniroute_enabled?) if assignment_type == :load_based_round_robin
        omni_group_unstub
        Freshid::V2::Models::Usergroup.unstub(:create)
        Account.current.groups.find_by_id(group_id).destroy
      end
    end

    def test_create_omni_group_with_omni_channel_routing_invalid
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:omni_channel_routing])
      groups_assignment_type_stubs(:omni_channel_routing) do
        post :create, construct_params({ version: 'private' }, group_params)
      end
      assert_response 400
      match_json([bad_request_error_pattern('automatic_agent_assignment[:type]', :not_included, code: :invalid_value, list: 'channel_specific')])
    ensure
      omni_group_unstub
    end

    def test_create_omni_group_with_chat_assignment_invalid
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(CHAT_ASSIGNMENT_SETTINGS[:intelli_assign_invalid])
      freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
      Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)
      groups_assignment_type_stubs(:round_robin) do
        post :create, construct_params({ version: 'private' }, group_params)
      end
      assert_response 400
      match_json([bad_request_error_pattern('automatic_agent_assignment[:settings][:assignment_type]', :not_included, code: :invalid_value, list: 'intelli_assign')])
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)
    end

    def test_create_omni_group_with_invalid_chat_assignment_capping_limit
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      intelli_assign_params = CHAT_ASSIGNMENT_SETTINGS[:intelli_assign]
      intelli_assign_params[:automatic_agent_assignment][:settings][1][:assignment_type_settings].merge!(capping_limit: 3)
      group_params.merge!(CHAT_ASSIGNMENT_SETTINGS[:intelli_assign])
      freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
      Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)
      groups_assignment_type_stubs(:round_robin) do
        post :create, construct_params({ version: 'private' }, group_params)
      end
      assert_response 400
      match_json([bad_request_error_pattern('automatic_agent_assignment[:settings][:assignment_type_settings][:capping_limit]', :invalid_field)])
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)
    end

    def test_create_omni_group_with_chat_assignment_valid
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(CHAT_ASSIGNMENT_SETTINGS[:intelli_assign])
      freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
      Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)

      groups_assignment_type_stubs(:round_robin) do
        post :create, construct_params({ version: 'private' }, group_params)
      end
      group_id = JSON.parse(response.body)['id']
      assert_response(201)
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)
      Account.current.groups.find_by_id(group_id).try(:destroy)
    end

    # show omni group test

    def test_show_invalid_omni_group_id
      omni_group_stub
      get :show, controller_params(version: 'private', id: 199_991)
      assert_response 404
    ensure
      omni_group_unstub
    end

    def test_show_invalid_omni_group_without_uid
      group = create_group(Account.current, agent_ids: [Account.current.agents.first.user_id])
      omni_group_stub
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 400
    ensure
      Account.current.groups.find(group.id).destroy
      omni_group_unstub
    end

    def test_show_invalid_omni_group_with_invalid_uid
      group = create_group(Account.current, agent_ids: [Account.current.agents.first.user_id], uid: "22446688224466006688")
      Freshid::V2::Models::Usergroup.stubs(:find_by_id).returns(nil)
      omni_group_stub
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 400
    ensure
      Account.current.groups.find(group.id).destroy
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:find_by_id)
    end

     def test_show_omni_group_valid
      group = create_group(Account.current, agent_ids: [Account.current.agents.first.user_id], uid: "22446688224466006688")
      freshid_group = Freshid::V2::Models::Usergroup.new({ name: group.name, description: group.description, id: group.uid, config: {}.to_json } )
      Freshid::V2::Models::Usergroup.stubs(:find_by_id).returns(freshid_group)
      omni_group_stub
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:find_by_id)
    end

    def test_show_omni_group_valid_with_assignment_settings
      group = create_group(Account.current, ticket_assign_type: 1, agent_ids: [Account.current.agents.first.user_id], uid: "22446688224466006688")
      freshid_group = Freshid::V2::Models::Usergroup.new({ name: group.name, description: group.description, id: group.uid, config: CHAT_ASSIGNMENT_SETTINGS[:intelli_assign].to_json } )
      Freshid::V2::Models::Usergroup.stubs(:find_by_id).returns(freshid_group)
      omni_group_stub
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(omni_group_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:find_by_id)
    end

    def test_delete_group_with_agent_search_publish_test
      group = create_group_with_agents(@account, agent_list: [@account.account_managers.first.id])
      RabbitmqWorker.clear
      delete :destroy, construct_params(id: group.id)
      assert_equal RabbitmqWorker.jobs.size, 1
      assert_equal RabbitmqWorker.jobs[0]['args'][0], 'users'
      assert_equal JSON.parse(RabbitmqWorker.jobs[0]['args'][1])['user_properties']['id'], @account.account_managers.first.id
    end

    def test_delete_omni_group
      omni_group_stub
      group_params = { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, business_calendar_id: Account.current.business_calendar.first.id,
                       type: 'support_agent_group', escalate_to: Account.current.account_managers.first.id, agent_ids: [Account.current.agents.first.user_id], unassigned_for: '30m' }
      group_params.merge!(ASSIGNMENT_SETTINGS[:no_assignment])
      freshid_user_group = Freshid::V2::Models::Usergroup.new(create_omni_group_param(group_params))
      Freshid::V2::Models::Usergroup.stubs(:create).returns(freshid_user_group)
      post :create, construct_params({ version: 'private' }, group_params)
      group_id = JSON.parse(response.body)['id']
      delete :destroy, construct_params(id: group_id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil Group.find_by_id(group_id)
    ensure
      omni_group_unstub
      Freshid::V2::Models::Usergroup.unstub(:create)
    end

    private

      def create_support_agent_groups(count)
        ids = []
        count.times do
          ids << create_group(Account.current, agent_ids: [Account.current.agents.first.user_id]).id
        end
        ids
      end

      def create_group(account, options = {})
        name = "#{Faker::Name.name}#{rand(1_000_000)}"
        group = FactoryGirl.build(:group, name: name)
        group.account_id = account.id
        group.description = Faker::Lorem.paragraph
        group.escalate_to = Account.current.agents.first.user_id
        group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
        group.agent_ids = options[:agent_ids] || [Account.current.agents.first.user_id]
        group.business_calendar_id = 1
        group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
        group.ticket_assign_type = options[:round_robin_type] if options[:round_robin_type]
        group.capping_limit = options[:capping_limit] if options[:capping_limit]
        group.uid = options[:uid] if options[:uid]
        group.save!
        group
      end

      def create_omni_group_param(group_params)
        {
          organisation_identifier: { domain: Account.current.organisation_from_cache.try(:domain) },
          usergroup: {
            id: '178040553263975512',
            name: group_params[:name],
            description: group_params[:description],
            account_id: @account.id.to_s,
            bundle_id: @account.omni_bundle_id.to_s,
            config: {
              business_calendar_id: group_params[:business_calendar_id],
              automatic_agent_assignment: group_params[:automatic_agent_assignment]
            }.to_json
          },
          members: []
        }
      end

      def omni_group_stub
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.any_instance.stubs(:omni_groups?).returns(true)
        Account.any_instance.stubs(:omni_bundle_id).returns('178040553247198292')
        Account.any_instance.stubs(:organisation_from_cache).returns(Organisation.new(id: 178040553184283730, domain: 'sme.freshworks.com'))
        user = @account.agents.first.user
        freshid_authorization = user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: 79797)
        User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
      end

      def omni_group_unstub
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.any_instance.unstub(:omni_groups?)
        Account.any_instance.unstub(:omni_bundle_id)
        Account.any_instance.unstub(:organisation_from_cache)
        User.any_instance.unstub(:freshid_authorization)
      end

      def groups_assignment_type_stubs(assignment_type)
        Account.any_instance.stubs(:features?).with(:round_robin).returns(true)
        Account.any_instance.stubs(:lbrr_by_omniroute_enabled?).returns(false) if assignment_type == :load_based_round_robin
        Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
        Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true) if assignment_type == :load_based_round_robin
        Account.any_instance.stubs(:lbrr_by_omniroute_enabled?).returns(true) if assignment_type == :lbrr_by_omniroute
        Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true) if [:lbrr_by_omniroute, :omni_channel_routing].include?(assignment_type)
        yield
      ensure
        Account.any_instance.unstub(:features?)
        Account.any_instance.unstub(:lbrr_by_omniroute_enabled?) if assignment_type == :load_based_round_robin
        Account.any_instance.unstub(:skill_based_round_robin_enabled?)
        Account.any_instance.unstub(:round_robin_capping_enabled?) if assignment_type == :load_based_round_robin
        Account.any_instance.unstub(:lbrr_by_omniroute_enabled?) if assignment_type == :lbrr_by_omniroute
        Account.any_instance.unstub(:omni_channel_routing_enabled?) if [:lbrr_by_omniroute, :omni_channel_routing].include?(assignment_type)
      end
  end
end
