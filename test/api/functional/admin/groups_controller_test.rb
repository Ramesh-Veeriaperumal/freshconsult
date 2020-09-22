# frozen_string_literal: true

require_relative '../../test_helper'

module Admin
  class GroupsControllerTest < ActionController::TestCase
    include GroupsTestHelper
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
    include PrivilegesHelper

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
      User.current.groups.order(:name).all.each do |group|
        pattern << group_management_v2_pattern(group)
      end

      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(pattern.ordered!)
    ensure
      Account.current.groups.where(id: group_ids).destroy_all
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_availability).returns(false)
    end

    def test_get_support_agent_groups
      group_ids = create_support_agent_groups(3)
      pattern = []
      User.current.groups.order(:name).all.each do |group|
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
      User.current.groups.order(:name).all.each do |group|
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

      group_id = create_group_private_api(Account.current, agent_ids: [User.first.id], group_type: GroupConstants::FIELD_GROUP_NAME).id

      pattern = []
      User.current.groups.field_agent_groups.order(:name).all.each do |group|
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

      10.times { create_group_private_api(Account.current, group_type: 2) }

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
      6.times { create_group_private_api(Account.current, group_type: 2) }
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
      create_support_agent_groups(10)
      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME, page: 1, per_page: 5)
      assert_response 200
      assert_equal((JSON.parse response.body).count, 5)
      assert_include response.header['Link'], 'api/_/admin/groups?type=support_agent_group&page=2&per_page=5'

      get :index, controller_params(version: 'private', type: GroupConstants::SUPPORT_GROUP_NAME, page: 2, per_page: 5)
      assert_equal((JSON.parse response.body).count, 5)
      assert_response 200
    ensure
      Account.current.groups.delete_all
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
      Account.any_instance.stubs(:features?).with(:round_robin).returns(false)
      Account.any_instance.unstub(:omni_agent_availability_dashboard_enabled?)
      Account.any_instance.unstub(:omni_channel_routing_enabled?)
      Account.unstub(:current)
    end

    ##

    # show tests

    def test_show_group_valid
      group = create_group_private_api(Account.current)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    # tests for all assignment_type

    def test_no_assignment_type
      group = create_group_private_api(Account.current, ticket_assign_type: 0)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_v2_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_round_robin_assignment_type
      group = create_group_private_api(Account.current, ticket_assign_type: 1)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_rr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_lbrr_assignment_type
      group = create_group_private_api(Account.current, ticket_assign_type: 1, capping_limit: 2)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_lbrr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_sbrr_assignment_type
      group = create_group_private_api(Account.current, ticket_assign_type: 2, capping_limit: 2)
      get :show, controller_params(version: 'private', id: group.id)
      assert_response 200
      match_json(group_management_sbrr_pattern(Group.find(group.id)))
    ensure
      Account.current.groups.find(group.id).destroy
    end

    def test_lbrr_by_onmiroute_type
      group = create_group_private_api(Account.current, ticket_assign_type: 12)
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
    
    # DELETE tests

    def test_delete_group_with_invalid_id
      delete :destroy, construct_params(id: Random.rand(1000..1010))
      assert_response 404
      assert_equal ' ', @response.body
    end

    def test_delete_group
      group = create_group_private_api(@account, ticket_assign_type: 2, capping_limit: 23)
      delete :destroy, construct_params(id: group.id)
      assert_equal ' ', @response.body
      assert_response 204
      assert_nil Group.find_by_id(group.id)
    end

    def test_delete_group_without_privilege
      group = create_group_private_api(@account, ticket_assign_type: 2, capping_limit: 23)
      remove_privilege(@agent, :manage_account)
      remove_privilege(@agent, :admin_tasks)
      delete :destroy, construct_params(id: group.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      add_privilege(@agent, :manage_account)
      add_privilege(@agent, :admin_tasks)
    end

    private

      def create_support_agent_groups(count)
        ids = []
        count.times do
          ids << create_group_private_api(Account.current, agent_ids: [User.first.id]).id
        end
        ids
      end
  end
end
