require_relative '../../test_helper'

module Ember
  class TicketFiltersControllerTest < ActionController::TestCase
    include QueryHashHelper
    include TicketFiltersHelper
    include GroupsTestHelper
    include AdvancedTicketingTestHelper

    def wrap_cname(params)
      { ticket_filter: params }
    end

    def setup
      super
      before_all
    end

    def before_all
      @account = Account.first.make_current
      Account.any_instance.stubs(:sla_management_v2_enabled?).returns(true)
      Account.any_instance.stubs(:auto_refresh_revamp_enabled?).returns(true)
      @agent = get_admin.make_current
    end

    # Tests
    # Actions: index, show, create, update and destroy [Each action with different params]

    def test_list_all_filters
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
    end

    def test_show_single_filter_with_invalid_id
      get :show, construct_params({ version: 'private' }, false).merge(id: 0)
      assert_response 404
      get :show, construct_params({ version: 'private' }, false).merge(id: :testing_id)
      assert_response 404
    end

    def test_show_single_filter
      filter1 = create_filter
      get :show, construct_params({ version: 'private' }, false).merge(id: filter1.id)
      assert_response 200
      match_custom_json(response.body, ticket_filter_show_pattern(filter1))
    end

    def test_show_inaccessible_filter
      group = create_group(@account)
      inaccessible_filter = create_filter(nil, custom_ticket_filter: {
                                            visibility: {
                                              visibility: 2,
                                              group_id: group.id
                                            }
                                          })
      get :show, construct_params({ version: 'private' }, false).merge(id: inaccessible_filter.id)
      assert_response 404
    end

    def test_show_invalid_filter
      group = create_group(@account)
      inaccessible_filter = create_filter(nil, custom_ticket_filter: {
                                            visibility: {
                                              visibility: 2,
                                              group_id: group.id
                                            }
                                          })
      get :show, construct_params({ version: 'private' }, false).merge(id: inaccessible_filter.id + 100)
      assert_response 404
    end

    def test_show_with_default_visible_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end

    def test_show_with_default_visible_ongoing_collab_filter
      Account.current.stubs(:collaboration_enabled?).returns(true)
      # stubbed called twice - one for function and other one to form expected json
      Collaboration::Ticket.any_instance.stubs(:fetch_collab_tickets).returns([])
      get :show, construct_params({ version: 'private' }, false).merge(id: 'ongoing_collab')
      Collaboration::Ticket.any_instance.expects(:fetch_collab_tickets).once
      assert_response 200
      Collaboration::Ticket.any_instance.stubs(:fetch_collab_tickets).returns([])
      match_custom_json(response.body, default_filter_pattern('ongoing_collab'))
      Account.current.unstub(:collaboration_enabled?)
      Collaboration::Ticket.any_instance.unstub(:fetch_collab_tickets)
    end

    def test_show_with_default_visible_non_ongoing_collab_filter
      Account.current.stubs(:collaboration_enabled?).returns(true)
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.first
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      Collaboration::Ticket.any_instance.expects(:fetch_collab_tickets).never
      Account.current.unstub(:collaboration_enabled?)
    end

    def test_show_with_default_hidden_filter
      default_filter_id = TicketsFilter.accessible_filters(TicketFilterConstants::HIDDEN_FILTERS).sample
      get :show, construct_params({ version: 'private' }, false).merge(id: default_filter_id)
      assert_response 200
      match_custom_json(response.body, default_filter_pattern(default_filter_id))
    end

    def test_create_with_invalid_params
      filter_params = sample_filter_input_params
      post :create, construct_params({ version: 'private' }, filter_params.except(:query_hash, :name))
      assert_response 400
      match_json([bad_request_error_pattern('query_hash', :datatype_mismatch, expected_data_type: Array),
                  bad_request_error_pattern('name', :missing_field)])
    end

    def test_create_with_invalid_values
      filter_params = sample_filter_input_params
      filter_params[:order_by] = 'agent_responded_at'
      filter_params[:visibility][:visibility] = ::Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.max + 1 # invalid visibility
      post :create, construct_params({ version: 'private' }, filter_params)
      assert_response 400
      match_json([bad_request_error_pattern('order_by', :not_included, list: sort_field_options.join(',')),
                  bad_request_error_pattern('visibility_id', :not_included, list: ::Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.join(','))])
    end

    def test_create_with_empty_query_hash
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      post :create, construct_params({ version: 'private' }, filter_params.merge(query_hash: []))
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_create_with_valid_params
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      post :create, construct_params({ version: 'private' }, filter_params)
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_create_with_due_by_without_feature
      Account.any_instance.stubs(:sla_management_v2_enabled?).returns(false)
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      post :create, construct_params({ version: 'private' }, filter_params)
      assert_response 400
    ensure
      Account.any_instance.stubs(:sla_management_v2_enabled?).returns(true)
    end

    def test_update_with_invalid_params
      filter1 = create_filter
      filter_params = sample_filter_input_params
      put :update, construct_params({ version: 'private', id: filter1.id }, filter_params.except(:query_hash, :name))
      assert_response 400
      match_json([bad_request_error_pattern('query_hash', :datatype_mismatch, expected_data_type: Array),
                  bad_request_error_pattern('name', :missing_field)])
    end


    def test_create_with_valid_params_without_feature
      @account.revoke_feature(:custom_ticket_views)
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name

      post :create, construct_params({ version: 'private' }, filter_params)
      assert_response 403
    ensure
      @account.add_feature(:custom_ticket_views)
    end


    def test_update_with_invalid_values
      filter1 = create_filter
      filter_params = sample_filter_input_params
      filter_params[:order_by] = 'requester_responded_at'
      filter_params[:visibility][:visibility] = ::Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.max + 1 # invalid visibility
      put :update, construct_params({ version: 'private', id: filter1.id }, filter_params)
      assert_response 400
      match_json([bad_request_error_pattern('order_by', :not_included, list: sort_field_options.join(',')),
                  bad_request_error_pattern('visibility_id', :not_included, list: ::Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.join(','))])
    end

    def test_update_default_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      put :update, construct_params({ version: 'private', id: default_filter_id }, sample_filter_input_params)
      assert_response 403
    end

    def test_update_with_empty_query_hash
      filter1 = create_filter
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      post :update, construct_params({ version: 'private', id: filter1.id }, filter_params.merge(query_hash: []))
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_update_with_valid_params
      filter1 = create_filter
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      put :update, construct_params({ version: 'private', id: filter1.id }, filter_params)
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_update_with_valid_params_without_visibility
      filter1 = create_filter
      filter_params = sample_filter_input_params
      new_name = "#{Faker::Name.name} - #{Time.zone.now}"
      filter_params[:name] = new_name
      put :update, construct_params({ version: 'private', id: filter1.id }, filter_params.except(:visibility))
      assert_response 200
      filter = Helpdesk::Filters::CustomTicketFilter.find_by_name(new_name)
      match_custom_json(response.body, ticket_filter_show_pattern(filter))
    end

    def test_destroy_filter_with_invalid_id
      get :destroy, construct_params({ version: 'private', id: 0 }, false)
      assert_response 404
      get :destroy, construct_params({ version: 'private', id: :testing_id }, false)
      assert_response 404
    end

    def test_destroy_default_filter
      default_filter_id = TicketsFilter.default_views.map { |a| a[:id] }.sample
      put :destroy, construct_params({ version: 'private', id: default_filter_id }, false)
      assert_response 403
    end

    def test_destroy_valid_filter
      filter2 = create_filter
      put :destroy, construct_params({ version: 'private', id: filter2.id }, false)
      assert_response 204
    end

    def test_list_all_filters_when_fsm_enabled
      enable_fsm do
        begin
          Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
          perform_fsm_operations
          get :index, controller_params.merge(version: 'private')
          assert_response 200
          match_custom_json(response.body, ticket_filter_index_pattern)
          fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'unresolved_service_tasks' }
          assert fsm_filter.present?
          assert_equal 'appointment_start_time', fsm_filter['order_by']
          assert_equal 'asc', fsm_filter['order_type']
        ensure
          Account.any_instance.unstub(:field_service_management_enabled?)
        end
      end
    end

    def test_list_all_filters_when_fsm_disabled
      Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
      fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'unresolved_service_tasks' }
      assert_equal nil, fsm_filter
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_unassigned_tasks_filter_present_when_fsm_enabled
      enable_fsm do
        begin
          Account.current.ticket_filters.where(name: 'Unassigned service tasks').destroy_all
          Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
          perform_fsm_operations
          get :index, controller_params.merge(version: 'private')
          assert_response 200
          match_custom_json(response.body, ticket_filter_index_pattern)
          fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'unassigned_service_tasks' }
          assert_not_nil fsm_filter
          assert_equal 'appointment_start_time', fsm_filter['order_by']
          assert_equal 'asc', fsm_filter['order_type']
        ensure
          Account.any_instance.unstub(:field_service_management_enabled?)
        end
      end
    end

    def test_unassigned_tasks_filter_not_present_when_fsm_disabled
      Account.current.ticket_filters.where(name: 'Unassigned service tasks').destroy_all
      Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
      fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'unassigned_service_tasks' }
      assert_nil fsm_filter
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_overdue_tasks_filter_present_when_fsm_enabled
      enable_fsm do
        begin
          Account.current.ticket_filters.where(name: 'Overdue service tasks').destroy_all
          Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
          perform_fsm_operations
          get :index, controller_params.merge(version: 'private')
          assert_response 200
          match_custom_json(response.body, ticket_filter_index_pattern)
          fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'overdue_service_tasks' }
          assert_not_nil fsm_filter
          assert_equal 'appointment_start_time', fsm_filter['order_by']
          assert_equal 'asc', fsm_filter['order_type']
        ensure
          Account.any_instance.unstub(:field_service_management_enabled?)
        end
      end
    end

    def test_overdue_tasks_filter_not_present_when_fsm_disabled
      Account.current.ticket_filters.where(name: 'Overdue service tasks').destroy_all
      Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
      fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'overdue_service_tasks' }
      assert_nil fsm_filter
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_service_tasks_due_today_filter_present_when_fsm_enabled
      enable_fsm do
        begin
          Account.current.ticket_filters.where(name: 'Service tasks due today').destroy_all
          Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
          perform_fsm_operations
          get :index, controller_params.merge(version: 'private')
          assert_response 200
          match_custom_json(response.body, ticket_filter_index_pattern)
          fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'service_tasks_due_today' }
          assert_not_nil fsm_filter
          assert_equal 'appointment_start_time', fsm_filter['order_by']
          assert_equal 'asc', fsm_filter['order_type']
        ensure
          Account.any_instance.unstub(:field_service_management_enabled?)
        end
      end
    end

    def test_service_tasks_due_today_filter_not_present_when_fsm_disabled
      Account.current.ticket_filters.where(name: 'Service tasks due today').destroy_all
      Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
      fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'service_tasks_due_today' }
      assert_nil fsm_filter
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_service_tasks_starts_today_filter_present_when_fsm_enabled
      enable_fsm do
        begin
          Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
          perform_fsm_operations
          get :index, controller_params.merge(version: 'private')
          assert_response 200
          match_custom_json(response.body, ticket_filter_index_pattern)
          fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'service_tasks_starting_today' }
          assert_not_nil fsm_filter
          assert_equal 'appointment_start_time', fsm_filter['order_by']
          assert_equal 'asc', fsm_filter['order_type']
        ensure
          Account.any_instance.unstub(:field_service_management_enabled?)
        end
      end
    end

    def test_service_tasks_starts_today_filter_not_present_when_fsm_disabled
      Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
      get :index, controller_params.merge(version: 'private')
      assert_response 200
      match_custom_json(response.body, ticket_filter_index_pattern)
      fsm_filter = JSON.parse(response.body).find { |x| x['id'] == 'service_tasks_starts_today' }
      assert_nil fsm_filter
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

  end
end
