require_relative '../../test_helper'
['dashboard_object.rb', 'widget_object.rb','search_service_result.rb'].each { |filename| require_relative "#{Rails.root}/test/api/helpers/custom_dashboard/#{filename}"}
require "#{Rails.root}/test/core/helpers/account_test_helper.rb"
require "#{Rails.root}/test/api/helpers/custom_dashboard_test_helper.rb"
module Ember
  class CustomDashboardControllerTest < ActionController::TestCase
    include ::Dashboard::Custom::CustomDashboardConstants
    include GroupsTestHelper
    include CustomDashboardTestHelper
    include QueryHashHelper
    include TicketFieldsTestHelper
    include SurveysTestHelper
    include LeaderboardTestHelper
    include Redis::RedisKeys
    include Redis::SortedSetRedis
    include ApiTicketsTestHelper
    include ProductsTestHelper
    include AccountTestHelper
    include Helpdesk::SharedOwnershipMigrationMethods

    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      return if @@before_all_run
      @account.set_custom_dashboard_limit({ dashboard: 25, widgets: { scorecard: 25, bar_chart: 25, csat: 25, leaderboard: 25, ticket_trend_card: 25, time_trend_card: 25, sla_trend_card: 25 } })
      @account.add_feature(:custom_dashboard)
      @account.dashboards.destroy_all
      create_dashboard_with_widgets(nil, 0, 0)
      create_dashboard_with_widgets(nil, 0, 0)
      @@group = create_group_with_agents(@account, { agent_list: [@agent.id] })
      create_dashboard_with_widgets({group_ids: @@group.id}, 0, 0)
      @@scorecard_dashboard = create_dashboard_with_widgets(nil, 2, 0)
      @@bar_chart_dashboard = create_dashboard_with_widgets(nil, 3, 1)
      # @@forum_moderation_dashboard = create_dashboard_with_widgets(nil, 1, 4)
      setup_for_csat_widget
      @@product = create_product
      @@ticket_trend_card_dashboard = create_dashboard_with_widgets(nil, 2, 5)
      @@time_trend_card_dashboard = create_dashboard_with_widgets(nil, 2, 6)
      @@sla_trend_card_dashboard = create_dashboard_with_widgets(nil, 2, 7)
      @@before_all_run = true
    end

    def setup_for_csat_widget
      @account.custom_survey_results.destroy_all
      survey_count_without_group = 4
      positive_survey_without_group = 4
      ticket = create_ticket
      positive_survey_without_group.times do
        create_survey_result(ticket, 103)
      end
      @@positive_survey_with_group = 4
      @@survey_count_with_group = 4
      @@csat_group = create_group_with_agents(@account, { agent_list: [@agent.id]})
      ticket = create_ticket({}, @@csat_group)
      @@positive_survey_with_group.times do
        create_survey_result(ticket, 103)
      end

      @@total_survey_count = @@survey_count_with_group + survey_count_without_group
      @@total_positive_survey_count = @@positive_survey_with_group + positive_survey_without_group
    end

    def dashboard_list
      @@dashboard_list ||= []
    end

    def update_dashboard_list(dashboard_object)
      self.dashboard_list << dashboard_object
    end

    def test_dashboard_index_403
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :index, controller_params({ version: 'private' }, false)
      assert_response 403
    end

    def test_dashboard_index_200
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :index, controller_params({ version: 'private' }, false)
      response_hash = JSON.parse(response.body).map(&:deep_symbolize_keys)
      assert_response 200
      match_dashboard_index_payload(response_hash, @@dashboard_list)
    end

    def test_dashboard_create_403
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      assert_response 403
    end

    def test_dashboard_create_201_global_access
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      update_dashboard_list(dashboard_object)
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
    end

    def test_dashboard_create_201_group_access
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      group = @account.groups.first
      dashboard_object = DashboardObject.new(2, [group.id])
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      update_dashboard_list(dashboard_object)
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
    end

    def test_dashboard_create_400_global_access_with_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      group = create_group_with_agents(@account, { agent_list: [@agent.id]})
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      dashboard_payload = dashboard_object.get_dashboard_payload
      dashboard_payload[:group_ids] = [group.id, group.id + rand(50..100)]
      post :create, controller_params(wrap_cname(dashboard_payload).merge!(version: 'private'), false)
      assert_response 400
    end

    def test_dashboard_create_400_group_access_without_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      dashboard_object = DashboardObject.new(2)
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      dashboard_payload = dashboard_object.get_dashboard_payload
      post :create, controller_params(wrap_cname(dashboard_payload).merge!(version: 'private'), false)
      assert_response 400
    end

    def test_dashboard_create_400_group_access_with_incorrect_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      group = create_group_with_agents(@account, { agent_list: [@agent.id]})
      dashboard_object = DashboardObject.new(2)
      dashboard_object.add_widget(0)
      dashboard_object.add_widget(0)
      dashboard_payload = dashboard_object.get_dashboard_payload
      dashboard_payload[:group_ids] = [group.id, group.id + rand(50..100)]
      post :create, controller_params(wrap_cname(dashboard_payload).merge!(version: 'private'), false)
      assert_response 400
    end

    def test_dashboard_show_403
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :show, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      assert_response 403
    end

    def test_dashboard_show_200_by_dashboard_admin
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :show, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 200
      match_dashboard_response(response_hash, @@dashboard_list.first.get_dashboard_payload)
    end

    def test_dashboard_show_200_by_agents
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :show, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 200
      match_dashboard_response(response_hash, @@dashboard_list.first.get_dashboard_payload)
    end

    def test_dashboard_show_404
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :show, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id + rand(1000..100_00) }, false)
      assert_response 404
    end

    def test_dashboard_update_403
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      put :update, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      assert_response 403
    end

    def test_dashboard_update_403_by_agents
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      put :update, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      assert_response 403
    end

    def test_dashboard_update_200_with_accessible_attributes
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { type: 2, group_ids: [@@group.id] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: @@dashboard_list.first.db_record.id, version: 'private'), false)
      assert_response 200
    end

    def test_dashboard_update_200_with_incorrect_accessible_attributes
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { type: 0, group_ids: [@@group.id] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: @@dashboard_list.first.db_record.id, version: 'private'), false)
      assert_response 400
    end    

    def test_dashboard_destroy_403_by_agents
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      delete :destroy, controller_params({ version: 'private', id: @@dashboard_list.first.db_record.id }, false)
      assert_response 403
    end

    def test_dashboard_destroy_204_by_dashboard_admin
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      delete :destroy, controller_params({ version: 'private', id: @@dashboard_list.delete(@@dashboard_list.first).db_record.id }, false)
      assert_response 204
    end

    def test_dashboard_destroy_404_by_dashboard_admin
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      delete :destroy, controller_params({ version: 'private', id: rand(1000..100_00) }, false)
      assert_response 404
    end

    # widgets_data response meta test case
    def test_widgets_data_api_meta
      stub_data = fetch_scorecard_stub(@@scorecard_dashboard.widgets)
      ::Dashboard::TrendCount.any_instance.stubs(:fetch_count).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, type: 'scorecard')
      assert_response 200
      assert_not_nil response.api_meta[:last_dump_time]
      assert_not_nil response.api_meta[:dashboard][:last_modified_since]
    ensure
      ::Dashboard::TrendCount.any_instance.unstub(:fetch_count)
    end
    # Basic preview API tests

    def test_widget_data_preview_without_access
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      get :widget_data_preview, controller_params(version: 'private')
      assert_response 403
    end

    def test_widget_data_preview_with_invalid_type
      get :widget_data_preview, controller_params(version: 'private', type: 'random_type')
      assert_response 400
    end

    def test_widget_data_preview_without_type
      get :widget_data_preview, controller_params(version: 'private')
      assert_response 400
    end
    # Scorecard preview tests

    def test_widget_data_preview_for_scorecard_with_invalid_config
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'invalid')
      assert_response 400
    end

    # def test_widget_data_preview_for_scorecard_with_count_cluster_down
    #   get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'unresolved')
    #   assert_response 500
    # end

    def test_widget_data_preview_for_scorecard_with_only_me_filter
      ticket_filter = create_filter(nil, only_me_accessibility)
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 400
    end

    def test_widget_data_preview_for_scorecard_without_filter
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard')
      assert_response 400
    end

    def test_widget_data_preview_for_scorecard_with_default_filter
      ::Dashboard::TrendCount.any_instance.stubs(:fetch_count).returns({ unresolved: 55 })
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'unresolved')
      assert_response 200
      match_json({ 'count' => 55 })
    end

    def test_widget_data_preview_for_scorecard_invalid_es_response
      options = { time_range: 3 }
      Account.current.launch(:es_msearch)
      dashboard = create_dashboard_with_widgets(nil, 1, 0, [options])
      ::Search::Filters::Docs.any_instance.stubs(:bulk_es_request).returns({ 'responses' => [{ 'error': { 'root_cause':'I dont know' } }, { 'took':2, 'timed_out':false, '_shards': { 'total':1, 'successful':1, 'failed':0 },'hits': { 'total':1, 'max_score':0.0, 'hits':[] }}] }.to_json)
      get :widgets_data, controller_params(version: 'private', type: 'scorecard', id: dashboard.id)
      assert_response 400
    ensure
      Account.current.rollback(:es_msearch)
    end

    def test_widget_data_preview_for_scorecard_with_custom_filter
      ticket_filter = create_filter
      ::Dashboard::TrendCount.any_instance.stubs(:fetch_count).returns({ :"#{ticket_filter.id}" => 87 })
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json({ 'count' => 87 })
    end

    def test_widget_data_preview_for_scorecard_with_custom_filter_with_comma_choices
      choices = ['Chennai, IN', 'Bangalore']
      @custom_field = create_custom_field_dropdown('test_custom_dropdown_scorecard_with_comma', choices)
      ticket_filter = create_filter(@custom_field)
      ::Dashboard::TrendCount.any_instance.stubs(:fetch_count).returns(:"#{ticket_filter.id}" => 87)
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 87)
    ensure
      @custom_field.destroy
    end

    def test_widget_data_preview_for_scorecard_with_none_custom_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'none' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 77 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 77)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_in_the_past_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'in_the_past' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 14 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 14)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_appointment_start_and_end_time
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => ' - 2019-12-12T23:59:59+00:00' },
                                  { 'condition' => 'flexifields.ff_date02', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_end_time', 'value' => '2019-12-22T23:59:59+00:00 - ' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 14 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 14)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_appointment_start_time
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => ' - 2019-12-12T23:59:59+00:00' },
                                  { 'condition' => 'flexifields.ff_date02', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_end_time', 'value' => ' ' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 14 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 14)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_appointment_end_time
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => ' ' },
                                  { 'condition' => 'flexifields.ff_date02', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_end_time', 'value' => '2019-12-22T23:59:59+00:00 - ' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 14 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 14)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_out_appointment_start_and_end_time
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => ' ' },
                                  { 'condition' => 'flexifields.ff_date02', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_end_time', 'value' => ' ' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 14 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 14)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_today_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'today' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 17 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 17)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_yesterday_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'yesterday' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 40 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 40)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_tomorrow_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'tomorrow' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 48 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 48)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_week_filter
      Account.current.launch(:count_service_es_reads)
      none_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'week' }] }
      ticket_filter = create_filter(nil, none_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 68 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 68)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_next_week_custom_filter
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'next_week' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 77 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 77)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_last_week_custom_filter
      Account.current.launch(:count_service_es_reads)
      filter_hash = { data_hash: [{ 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => 'cf_fsm_appointment_start_time', 'value' => 'last_week' }] }
      ticket_filter = create_filter(nil, filter_hash)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 77 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 77)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    # Bar chart preview tests

    def test_widget_data_preview_for_bar_chart_with_invalid_filter
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'invalid', categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_without_filter
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_without_field
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'all_tickets', representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_without_representation
      field = Account.current.ticket_fields.find_by_field_type('default_source')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_invalid_ticket_field
      field_id = Helpdesk::TicketField.maximum("id") + 100
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'all_tickets', categorised_by: field_id, representation: PERCENTAGE)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_invalid_representation
      field = Account.current.ticket_fields.find_by_field_type('default_priority')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'all_tickets', categorised_by: field.id, representation: 3)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_only_me_filter
      ticket_filter = create_filter(nil, only_me_accessibility)
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_text_field
      field = Account.current.ticket_fields.find_by_field_type('default_subject')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_requester_field
      field = Account.current.ticket_fields.find_by_field_type('default_requester')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_company_field
      field = Account.current.ticket_fields.find_by_field_type('default_company')
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 400
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter
      ticket_filter = create_filter
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter_with_comma_choices
      choices = ['Chennai, IN', 'Bangalore']
      @custom_field = create_custom_field_dropdown('test_custom_dropdown_barchart_with_comma', choices)
      field2 = Account.current.ticket_fields.where(field_type: 'default_group').first
      ticket_filter = create_filter(@custom_field)
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field2.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field2.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field2.id))
    ensure
      @custom_field.destroy
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter_categorized_by_field_with_comma_choices
      choices = ['Chennai, IN', 'Bangalore']
      field = create_custom_field_dropdown('test_custom_dropdown_barchart_with_comma', choices)
      ticket_filter = create_filter
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id, field.choices))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id, field.choices))
    ensure
      field.destroy
    end

    def test_widget_data_preview_for_bar_chart_with_default_filter
      field = Account.current.ticket_fields.find_by_field_type('default_group')
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    end

    def test_widget_data_preview_for_bar_chart_with_default_field
      field = Account.current.ticket_fields.find_by_field_type('default_agent')
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    end

    def test_widget_data_preview_for_bar_chart_with_custom_field
      choices = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon']
      field = create_custom_field_dropdown('test_custom_dropdown_bar_chart', choices)
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id, choices))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id, choices))
    end

    def test_widget_data_preview_for_bar_chart_with_numeric_values
      choices = ['Get Smart 123', '123 Pursuit of Happiness', '123']
      field = create_custom_field_dropdown('test_custom_dropdown_bar_chart', choices)
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id, choices))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id, choices))
    end

    def test_widget_data_preview_for_bar_chart_with_number_field
      field = Account.current.ticket_fields.find_by_field_type('default_agent')
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    end

    def test_widget_data_preview_for_bar_chart_with_percentage_representation
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: PERCENTAGE)
      assert_response 200
      match_json(bar_chart_preview_response_percentage_pattern(field.id))
    end

    def test_widget_data_preview_for_bar_chart_with_internal_group_percentage_representation
      enable_feature(:shared_ownership) do
        add_internal_fields
        field = Account.current.ticket_fields.find_by_field_type('default_internal_group')
        ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
        get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: PERCENTAGE)
        assert_response 200
        match_json(bar_chart_preview_response_percentage_pattern(field.id))
        delete_internal_fields
      end
    end

    def test_widget_data_preview_for_bar_chart_internal_agent_with_percentage_representation
      enable_feature(:shared_ownership) do
        add_internal_fields
        field = Account.current.ticket_fields.find_by_field_type('default_internal_agent')
        ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(bar_chart_preview_es_response_stub(field.id))
        get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: PERCENTAGE)
        assert_response 200
        match_json(bar_chart_preview_response_percentage_pattern(field.id))
        delete_internal_fields
      end
    end

    def test_widget_data_preview_for_ticket_trend_card_with_invalid_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 'invalid')
      assert_response 400
    end

    def test_widget_data_preview_for_ticket_trend_card_with_invalid_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 2, date_range: 6)
      assert_response 400
    end

    def test_widget_data_preview_for_ticket_trend_card_with_invalid_group_id
      invalid_group_id = (Account.current.groups.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 1, group_ids: [invalid_group_id])
      assert_response 400
    end

    def test_widget_data_preview_for_ticket_trend_card_with_invalid_product_id
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 2, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_product_id_multiproduct_not_enabled
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      Account.any_instance.stubs(:multi_product_enabled?).returns(false)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_ticket_trend_card_without_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', date_range: 1)
      assert_response 400
    end

    def test_widget_data_preview_for_ticket_trend_card_without_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 1)
      assert_response 400
    end

    def test_widget_data_preview_for_ticket_trend_card_without_group_ids
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    end

    def test_widget_data_preview_for_ticket_trend_card_without_product_id
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_all_products
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, product_id: 0)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_multiple_groups
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..3)
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, group_ids: valid_group_ids)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_all_groups
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, group_ids: [0])
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_invalid_ticket_type
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, ticket_type: '55555')
      assert_response 400, response.body
    end

    def test_widget_data_preview_for_ticket_trend_card_with_ticket_type
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, ticket_type: ticket_type_picklist_value('Incident'))
      assert_response 200, response.body
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_create_dashboard_with_time_trends_widget_and_ticket_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(5, widget_config_data(ticket_type: ticket_type_picklist_value('Question')))
      update_dashboard_list(dashboard_object)
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_time_trends_widget_and_invalid_ticket_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(5, widget_config_data(ticket_type: '55555'))
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_time_trends_widget_and_all_ticket_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(5, widget_config_data(ticket_type: '0'))
      update_dashboard_list(dashboard_object)
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201, response_hash
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_product_id
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_ticket_trend_card_with_valid_config
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..2)
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'ticket_trend_card', metric: 3, date_range: 3, group_ids: valid_group_ids, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_time_trend_card_with_invalid_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 'invalid')
      assert_response 400
    end

    def test_widget_data_preview_for_time_trend_card_with_invalid_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5, date_range: 6)
      assert_response 400
    end

    def test_widget_data_preview_for_time_trend_card_with_invalid_group_id
      invalid_group_id = (Account.current.groups.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5, date_range: 1, group_ids: [invalid_group_id])
      assert_response 400
    end

    def test_widget_data_preview_for_time_trend_card_with_invalid_product_id
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 6, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_time_trend_card_with_product_id_multiproduct_not_enabled
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      Account.any_instance.stubs(:multi_product_enabled?).returns(false)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 7, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_time_trend_card_without_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', date_range: 1)
      assert_response 400
    end

    def test_widget_data_preview_for_time_trend_card_without_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5)
      assert_response 400
    end

    def test_widget_data_preview_for_time_trend_card_without_group_ids
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 7, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    end

    def test_widget_data_preview_for_time_trend_card_without_product_id
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 4, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_time_trend_card_with_all_products
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5, date_range: 3, product_id: 0)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_time_trend_card_with_all_groups
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5, date_range: 3, group_ids: [0])
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_time_trend_card_with_multiple_groups
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..3)
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 4, date_range: 3, group_ids: valid_group_ids)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_time_trend_card_with_product_id
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 6, date_range: 3, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_time_trend_card_with_valid_config
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..2)
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'time_trend_card', metric: 5, date_range: 3, group_ids: valid_group_ids, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_sla_trend_card_with_invalid_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 'invalid')
      assert_response 400
    end

    def test_widget_data_preview_for_sla_trend_card_with_invalid_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 8, date_range: 7)
      assert_response 400
    end

    def test_widget_data_preview_for_sla_trend_card_with_invalid_group_id
      invalid_group_id = (Account.current.groups.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 1, group_ids: [invalid_group_id])
      assert_response 400
    end

    def test_widget_data_preview_for_sla_trend_card_with_invalid_product_id
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 10, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_sla_trend_card_with_product_id_multiproduct_not_enabled
      invalid_product_id = (Account.current.products.maximum(:id) || 0) + 20
      Account.any_instance.stubs(:multi_product_enabled?).returns(false)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 1, product_id: invalid_product_id)
      assert_response 400
    ensure
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_sla_trend_card_without_metric
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', date_range: 1)
      assert_response 400
    end

    def test_widget_data_preview_for_sla_trend_card_without_date_range
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 10)
      assert_response 400
    end

    def test_widget_data_preview_for_sla_trend_card_without_group_ids
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 8, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    end

    def test_widget_data_preview_for_sla_trend_card_without_product_id
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 3)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_sla_trend_card_with_all_products
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 3, product_id: 0)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_sla_trend_card_with_all_groups
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 8, date_range: 3, group_ids: [0])
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_sla_trend_card_with_multiple_groups
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..3)
      stub_data = trend_card_reports_response_stub
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 8, date_range: 3, group_ids: valid_group_ids)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_sla_trend_card_with_product_id
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 3, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widget_data_preview_for_sla_trend_card_with_valid_config
      valid_group_ids = Account.current.groups_from_cache.map(&:id).slice(0..2)
      stub_data = trend_card_reports_response_stub
      Account.any_instance.stubs(:multi_product_enabled?).returns(true)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widget_data_preview, controller_params(version: 'private', type: 'sla_trend_card', metric: 9, date_range: 3, group_ids: valid_group_ids, product_id: @@product.id)
      assert_response 200
      match_json(trend_card_preview_response_pattern(stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
      Account.any_instance.unstub(:multi_product_enabled?)
    end

    def test_widgets_data_with_invalid_type
      dashboard = create_dashboard_with_widgets(nil, 1, 0)
      get :widgets_data, controller_params(version: 'private', id: dashboard.id, type: 'bar_graph')
      assert_response 400
    end

    def test_widgets_data_for_scorecard_in_dashboard_without_scorecard
      get :widgets_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, type: 'scorecard')
      assert_response 200
      match_json([])
    end

    def test_widgets_data_for_bar_chart_in_dashboard_without_bar_chart
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'bar_chart')
      assert_response 200
      match_json([])
    end

    def test_widgets_data_for_ticket_trend_card_in_dashboard_without_trend_card
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'ticket_trend_card')
      assert_response 200
      match_json([])
    end

    def test_widgets_data_for_time_trend_card_in_dashboard_without_trend_card
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'time_trend_card')
      assert_response 200
      match_json([])
    end

    def test_widgets_data_for_sla_trend_card_in_dashboard_without_trend_card
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'sla_trend_card')
      assert_response 200
      match_json([])
    end

    def test_bar_chart_data_for_invalid_widget
      widget = @@bar_chart_dashboard.widgets.last
      invalid_widget_id = widget.id + 40
      get :bar_chart_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, widget_id: invalid_widget_id)
      assert_response 404
    end

    def test_widgets_data_for_scorecard_widgets
      stub_data = fetch_scorecard_stub(@@scorecard_dashboard.widgets)
      ::Dashboard::TrendCount.any_instance.stubs(:fetch_count).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'scorecard')
      assert_response 200
      match_json(scorecard_response_pattern(@@scorecard_dashboard.widgets, stub_data))
    ensure
      ::Dashboard::TrendCount.any_instance.unstub(:fetch_count)
    end

    def test_widgets_data_for_bar_chart_widgets
      stub_data = fetch_bar_chart_stub(@@bar_chart_dashboard.widgets)
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, type: 'bar_chart')
      assert_response 200
      match_json(bar_chart_response_pattern(@@bar_chart_dashboard.widgets, stub_data))
    ensure
      ::Search::Dashboard::Custom::Count.any_instance.unstub(:fetch_count)
    end

    def test_bar_chart_data_for_bar_chart_widget
      widget = @@bar_chart_dashboard.widgets.first
      stub_data = bar_chart_data_es_response_stub(widget)
      ::Search::Dashboard::Custom::Count.any_instance.stubs(:fetch_count).returns(stub_data)
      stub_data = bar_chart_data_es_response_service_stub(widget)
      ::SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :bar_chart_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, widget_id: widget.id)
      assert_response 200
      match_json(bar_chart_data_response_pattern(widget))
    ensure
      ::SearchService::Client.any_instance.unstub(:multi_aggregate)
    end

    def test_widgets_data_for_ticket_trend_card_widgets
      stub_data = fetch_trend_card_stub(@@ticket_trend_card_dashboard.widgets)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@ticket_trend_card_dashboard.id, type: 'ticket_trend_card')
      assert_response 200
      match_json(trend_card_response_pattern(@@ticket_trend_card_dashboard.widgets, stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widgets_data_for_time_trend_card_widgets
      stub_data = fetch_trend_card_stub(@@time_trend_card_dashboard.widgets)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@time_trend_card_dashboard.id, type: 'time_trend_card')
      assert_response 200
      match_json(trend_card_response_pattern(@@time_trend_card_dashboard.widgets, stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widgets_data_for_sla_trend_card_widgets
      stub_data = fetch_trend_card_stub(@@sla_trend_card_dashboard.widgets)
      ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@sla_trend_card_dashboard.id, type: 'sla_trend_card')
      assert_response 200
      match_json(trend_card_response_pattern(@@sla_trend_card_dashboard.widgets, stub_data))
    ensure
      ::Dashboard::RedshiftRequester.any_instance.unstub(:fetch_records)
    end

    def test_widget_data_preview_for_forum_moderation_403_by_agent
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'forum_moderation')
      assert_response 403
    end

    def test_widget_data_preview_for_forum_moderation_200_by_dashboard_admin
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'forum_moderation')
      assert_response 400
    end

    def test_widgets_data_for_forum_moderation_widgets
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'forum_moderation')
      assert_response 400
    end

    def test_widget_data_preview_for_csat_403_by_agent
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat')
      assert_response 403
    end

    def test_widget_data_preview_for_csat_400_without_feature_by_dashboard_admin
      Account.any_instance.stubs(:new_survey_enabled?).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '3')
      assert_response 403
    end

    def test_widget_data_preview_for_csat_200_without_groups_monthly_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '3')
      assert_response 200
      match_json({ survey_responded: @@total_survey_count, results: [{ label: 'positive', value: (@@total_positive_survey_count * 100) / (@@total_survey_count)}, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widget_data_preview_for_csat_200_without_groups_weekly_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '2')
      assert_response 200
      match_json({ survey_responded: @@total_survey_count, results: [{ label: 'positive', value: (@@total_positive_survey_count * 100) / (@@total_survey_count) }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widget_data_preview_for_csat_200_without_groups_daily_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '1')
      assert_response 200
      match_json({ survey_responded: @@total_survey_count, results: [{ label: 'positive', value: (@@total_positive_survey_count * 100) / (@@total_survey_count) }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widget_data_preview_for_csat_200_with_group_monthly_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '5', group_ids: [@@csat_group.id])
      assert_response 200
      match_json({ survey_responded: @@survey_count_with_group, results: [{ label: 'positive', value: (@@positive_survey_with_group * 100) / (@@survey_count_with_group) }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widget_data_preview_for_csat_400_with_invalid_group
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '3', group_ids: [@@csat_group.id + rand(10_00..100_00)])
      assert_response 400
    end

    def test_widget_data_preview_for_csat_400_with_invalid_timerange
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '6')
      assert_response 400
    end

    def test_widget_data_preview_for_csat_200_with_group_daily_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '4', group_ids: [@@csat_group.id])
      assert_response 200
      match_json({ survey_responded: @@survey_count_with_group, results: [{ label: 'positive', value: (@@positive_survey_with_group * 100) / (@@survey_count_with_group) }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widget_data_preview_for_csat_200_with_group_weekly_filter
      Account.any_instance.stubs(:new_survey_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'csat', time_range: '2', group_ids: [@@csat_group.id])
      assert_response 200
      match_json({ survey_responded: @@survey_count_with_group, results: [{ label: 'positive', value: (@@positive_survey_with_group * 100) / (@@survey_count_with_group) }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
    end

    def test_widgets_data_for_csat_widgets_with_time_range_and_groups
      @account.custom_survey_results.destroy_all
      positive_survey = 4
      survey_count = positive_survey
      group = create_group_with_agents(@account, { agent_list: [@agent.id]})
      options = { time_range: 3, group_ids: [group.id] }
      csat_dashboard = create_dashboard_with_widgets(nil, 1, 2, [options])
      ticket = create_ticket({}, group)
      positive_survey.times do
        create_survey_result(ticket, 103)
      end
      get :widgets_data, controller_params(version: 'private', id: csat_dashboard.id, type: 'csat')
      response_data = JSON.parse(response.body)
      match_custom_json(response_data.first['widget_data'], { survey_responded: survey_count, results: [{ label: 'positive', value: (positive_survey * 100) / survey_count }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }]})
      assert_response 200
    end

    def test_widgets_data_for_csat_widgets_with_time_range_only
      @account.custom_survey_results.destroy_all
      options = { time_range: 3 }
      positive_survey = 4
      survey_count = positive_survey
      csat_dashboard = create_dashboard_with_widgets(nil, 1, 2, [options])
      ticket = create_ticket
      positive_survey.times do
        create_survey_result(ticket, 103)
      end
      get :widgets_data, controller_params(version: 'private', id: csat_dashboard.id, type: 'csat')
      response_data = JSON.parse(response.body)
      match_custom_json(response_data.first['widget_data'], { survey_responded: survey_count, results: [{ label: 'positive', value: (positive_survey * 100) / survey_count }, { label: 'negative', value: 0 }, { label: 'neutral', value: 0 }] })
      assert_response 200
    end

    def test_widget_data_preview_for_leaderboard_403_without_feature
      Account.any_instance.stubs(:gamification_enabled?).returns(false)
      Account.any_instance.stubs(:gamification_enable_enabled?).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'leaderboard')
      assert_response 403
    end

    def test_widget_data_preview_for_leaderboard_403_by_agent
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :widget_data_preview, controller_params(version: 'private', type: 'leaderboard')
      assert_response 403
    end

    # Has test case with and without group filter
    def test_widget_data_preview_for_leaderboard
      @current_month = Time.zone.now.month
      Account.any_instance.stubs(:gamification_enabled?).returns(true)
      Account.any_instance.stubs(:gamification_enable_enabled?).returns(true)
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)

      create_group_agents

      odd_score = {}
      even_score = {}
      score = {}

      clear_redis_data
      clear_group_agents_redis_data(@group_odd, @group_even)

      categories.each do |category|
        # building group odd leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_odd
        odd_score [category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        # building group even leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_even
        even_score[category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)

        # building account level leaderboard in redis
        redis_key = agents_leaderboard_key category.to_s
        create_account_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        create_account_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)
        score[category] = even_score[category] + odd_score[category]
      end
      assert_widget_data_preview_leaderboard_response score, { test_endpoint: :widget_data_preview } # account level leaderboard assertion
      assert_widget_data_preview_leaderboard_response odd_score, { group_id: @group_odd.id, test_endpoint: :widget_data_preview } # group level leaderboard assertion
      assert_widget_data_preview_leaderboard_response even_score, { group_id: @group_even.id, test_endpoint: :widget_data_preview } # group level leaderboard assertion

      clear_redis_data
      clear_group_agents_redis_data(@group_odd)
      clear_group_agents_redis_data(@group_even)
    end

    def test_widgets_data_for_leaderboard
      @current_month = Time.zone.now.month
      Account.any_instance.stubs(:gamification_enabled?).returns(true)
      Account.any_instance.stubs(:gamification_enable_enabled?).returns(true)
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)

      create_group_agents

      odd_score = {}
      even_score = {}
      score = {}

      clear_redis_data
      clear_group_agents_redis_data(@group_odd, @group_even)

      categories.each do |category|
        # building group odd leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_odd
        odd_score [category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        # building group even leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_even
        even_score[category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)

        # building account level leaderboard in redis
        redis_key = agents_leaderboard_key category.to_s
        create_account_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        create_account_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)
        score[category] = even_score[category] + odd_score[category]
      end
      account_leaderboard = create_dashboard_with_widgets(nil, 1, 3)
      odd_group_leaderboard = create_dashboard_with_widgets(nil, 1, 3, [{ group_id: @group_odd.id }])
      even_group_leaderboard = create_dashboard_with_widgets(nil, 1, 3, [{ group_id: @group_even.id }])
      assert_widget_data_preview_leaderboard_response score, { dashboard_id: account_leaderboard.id, test_endpoint: :widgets_data } # account level leaderboard assertion
      assert_widget_data_preview_leaderboard_response odd_score, { dashboard_id: odd_group_leaderboard.id, group_id: @group_odd.id, test_endpoint: :widgets_data } # group level leaderboard assertion
      assert_widget_data_preview_leaderboard_response even_score, { dashboard_id: even_group_leaderboard.id, group_id: @group_even.id, test_endpoint: :widgets_data }# group level leaderboard assertion

      clear_redis_data
      clear_group_agents_redis_data(@group_odd)
      clear_group_agents_redis_data(@group_even)
    end

    # To check service writes test
    def test_widgets_data_api_meta_from_search_service
      Account.current.launch(:count_service_es_reads)
      stub_data = fetch_search_service_scorecard_stub(@@scorecard_dashboard.widgets)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, type: 'scorecard')
      assert_response 200
      assert_not_nil response.api_meta[:last_dump_time]
      assert_not_nil response.api_meta[:dashboard][:last_modified_since]
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

     def test_widget_data_preview_for_scorecard_with_default_filter_from_search_service
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new({"records" => {"results" => { "unresolved" => { "total" => 55 } }} }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'unresolved')
      assert_response 200
      match_json({ 'count' => 55 })
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_custom_filter_from_search_service
      ticket_filter = create_filter
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new({"records" => { "results" => {"#{ticket_filter.id}" => {"total" => 87} }}}))
      # ::Dashboard::SearchServiceTrendCount.any_instance.stubs(:fetch_count).returns({ "results" => {"#{ticket_filter.id}" => {"total" => 87} }})
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json({ 'count' => 87 })
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_custom_filter_with_comma_choices_from_search_service
      choices = ['Chennai, IN', 'Bangalore']
      @custom_field = create_custom_field_dropdown('test_custom_dropdown_scorecard_with_comma', choices)
      ticket_filter = create_filter(@custom_field)
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 87)
    ensure
      @custom_field.destroy
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_scorecard_with_custom_filter_with_special_chars_from_search_service_new_fql
      choices = ['\'Chennai" \\IN', 'Bangalore']
      @custom_field = create_custom_field_dropdown('test_custom_dropdown_scorecard_with_comma', choices)
      ticket_filter = create_filter(@custom_field)
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:dashboard_java_fql_performance_fix)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { ticket_filter.id.to_s => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: ticket_filter.id)
      assert_response 200
      match_json('count' => 87)
    ensure
      @custom_field.destroy
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:dashboard_java_fql_performance_fix)
    end

    def test_widgets_data_preview_for_scorecard_with_unassigned_service_tasks_filter_from_search_new_fql
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:dashboard_java_fql_performance_fix)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { 'unassigned_service_tasks' => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'unassigned_service_tasks')
      assert_response 200
      match_json('count' => 87)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:dashboard_java_fql_performance_fix)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_widgets_data_preview_for_scorecard_with_overdue_service_tasks_filter_from_search_new_fql
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:dashboard_java_fql_performance_fix)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { 'overdue_service_tasks' => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'overdue_service_tasks')
      assert_response 200
      match_json('count' => 87)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:dashboard_java_fql_performance_fix)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_widgets_data_preview_for_scorecard_with_service_tasks_due_today_filter_from_search_new_fql
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:dashboard_java_fql_performance_fix)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { 'service_tasks_due_today' => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'service_tasks_due_today')
      assert_response 200
      match_json('count' => 87)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:dashboard_java_fql_performance_fix)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_widgets_data_preview_for_scorecard_with_service_tasks_starting_today_filter_from_search_new_fql
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:dashboard_java_fql_performance_fix)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(SearchServiceResult.new('records' => { 'results' => { 'service_tasks_starting_today' => { 'total' => 87 } } }))
      get :widget_data_preview, controller_params(version: 'private', type: 'scorecard', ticket_filter_id: 'service_tasks_starting_today')
      assert_response 200
      match_json('count' => 87)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:dashboard_java_fql_performance_fix)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter_from_search_service
      ticket_filter = create_filter
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id, ticket_filter.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_default_filter_from_search_service
      field = Account.current.ticket_fields.find_by_field_type('default_group')
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_default_field_from_search_service
      field = Account.current.ticket_fields.find_by_field_type('default_agent')
      Account.current.launch(:count_service_es_reads) 
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
      ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_custom_field_from_search_service
      choices = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon']
      field = create_custom_field_dropdown('test_custom_dropdown_bar_chart', choices)
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id, 'unresolved', choices))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id, choices))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_number_field_from_search_service
      field = Account.current.ticket_fields.find_by_field_type('default_agent')
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_percentage_representation_from_search_service
      field = Account.current.ticket_fields.find_by_field_type('default_status')
      Account.current.launch(:count_service_es_reads)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: 'unresolved', categorised_by: field.id, representation: PERCENTAGE)
      assert_response 200
      match_json(bar_chart_preview_response_percentage_pattern(field.id))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter_with_comma_choices_search_service
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:wf_comma_filter_fix)
      choices = ['Chennai, IN', 'Bangalore']
      @custom_field = create_custom_field_dropdown('test_custom_dropdown_barchart_with_comma', choices)
      field2 = Account.current.ticket_fields.where(field_type: 'default_status').first
      ticket_filter = create_filter(@custom_field)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field2.id))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field2.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field2.id))
    ensure
      @custom_field.destroy
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:wf_comma_filter_fix)
    end

    def test_widget_data_preview_for_bar_chart_with_custom_filter_categorized_by_field_with_comma_choices_search_service
      choices = ['Chennai, IN', 'Bangalore']
      field = create_custom_field_dropdown('test_custom_dropdown_barchart_with_comma', choices)
      ticket_filter = create_filter
      Account.current.launch(:count_service_es_reads)
      Account.current.launch(:wf_comma_filter_fix)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(bar_chart_preview_search_service_es_response_stub(field.id, ticket_filter.id, choices))
      get :widget_data_preview, controller_params(version: 'private', type: 'bar_chart', ticket_filter_id: ticket_filter.id, categorised_by: field.id, representation: NUMBER)
      assert_response 200
      match_json(bar_chart_preview_response_pattern(field.id, choices))
    ensure
      field.destroy
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      Account.current.rollback(:wf_comma_filter_fix)
    end

    def test_widgets_data_for_scorecard_widgets_from_search_service
      Account.current.launch(:count_service_es_reads)
      stub_data = fetch_search_service_scorecard_stub(@@scorecard_dashboard.widgets)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@scorecard_dashboard.id, type: 'scorecard')
      assert_response 200
      match_json(scorecard_response_pattern_search_service(@@scorecard_dashboard.widgets, stub_data))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_widgets_data_for_bar_chart_widgets_from_search_service
      Account.current.launch(:count_service_es_reads)
      stub_data = fetch_bar_chart_from_service_stub(@@bar_chart_dashboard.widgets)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :widgets_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, type: 'bar_chart')
      assert_response 200
      match_json(bar_chart_from_service_response_pattern(@@bar_chart_dashboard.widgets, stub_data))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_bar_chart_data_for_bar_chart_widget_from_search_service
      widget = @@bar_chart_dashboard.widgets.first
      Account.current.launch(:count_service_es_reads)
      stub_data = bar_chart_data_es_response_service_stub(widget)
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :bar_chart_data, controller_params(version: 'private', id: @@bar_chart_dashboard.id, widget_id: widget.id)
      assert_response 200
      match_json(bar_chart_data_response_pattern(widget))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_create_announcement_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      post :create_announcement, controller_params(wrap_cname(announcement_text: 'Sample text').merge!(id: @@bar_chart_dashboard.id, version: 'private'), false)
      assert_response 403
    end

    def test_create_announcement_with_invalid_field
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      post :create_announcement, controller_params(wrap_cname(active: 'Sample text').merge!(id: @@bar_chart_dashboard.id, version: 'private'), false)
      assert_response 400
    end

    def test_create_announcement_for_invalid_dashboard
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      post :create_announcement, controller_params(wrap_cname(announcement_text: 'Sample text').merge!(id: @@dashboard_list.first.db_record.id + rand(1000..100_00), version: 'private'), false)
      assert_response 404
    end

    def test_create_announcement_without_announcement_text
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      post :create_announcement, controller_params(wrap_cname({}).merge!(id: @@dashboard_list.first.db_record.id, version: 'private'), false)
      assert_response 400
    end

    def test_create_announcement_with_invalid_length
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      invalid_text = 'This is a text which has more than 150 characters, which has to invalidate annoucement create. kja skcn askcnsckas cksn sacn kiscn skanc sakcsakcna scksanc skcnsa cksn csaknc skcnsa kcnasc ksncsakcnsa c'
      post :create_announcement, controller_params(wrap_cname(announcement_text: invalid_text).merge!(id: @@scorecard_dashboard.id, version: 'private'), false)
      assert_response 400
    end

    def test_create_announcement
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      announcement_text = 'Hey, a new annoucement'
      dashboard_id = @@scorecard_dashboard.id
      post :create_announcement, controller_params(wrap_cname(announcement_text: announcement_text).merge!(id: dashboard_id, version: 'private', announcement_text: announcement_text), false)
      assert_response 200
      match_announcement_response(JSON.parse(response.body), announcement_text, dashboard_id)
    end

    def test_end_announcement_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      put :end_announcement, controller_params(wrap_cname(deactivate: true).merge!(id: @@bar_chart_dashboard.id, version: 'private'), false)
      assert_response 403
    end

    def test_end_announcement_without_any_announcement
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      put :end_announcement, controller_params(wrap_cname(deactivate: true).merge!(id: @@bar_chart_dashboard.id, version: 'private'), false)
      assert_response 404
    end

    def test_end_announcement
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      put :end_announcement, controller_params(wrap_cname(deactivate: true).merge!(id: @@scorecard_dashboard.id, version: 'private'), false)
      assert_response 200
    end

    def test_get_announcements_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      get :get_announcements, controller_params(id: @@scorecard_dashboard.id, version: 'private')
      assert_response 403
    end

    def test_get_announcements
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      get :get_announcements, controller_params(id: @@scorecard_dashboard.id, version: 'private')
      assert_response 200
      match_announcements_index(JSON.parse(response.body))
    end

    def test_fetch_announcement_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(false)
      get :fetch_announcement, controller_params(id: @@scorecard_dashboard.id, version: 'private')
      assert_response 403
    end

    def test_fetch_announcement
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      user_ids = [21, 4234, 4342]
      Ember::CustomDashboardController.any_instance.stubs(:fetch_data_from_service).returns(iris_stub(user_ids))
      announcement = @@scorecard_dashboard.announcements.first
      get :fetch_announcement, controller_params(id: @@scorecard_dashboard.id, announcement_id: announcement.id, version: 'private')
      assert_response 200
      match_announcement_show(JSON.parse(response.body), announcement, user_ids)
    end

    def test_dashboard_crud_flow_with_freshcaller_call_trend_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(18, view: 1, queue_id: 0, time_type: 1, source: 'freshcaller')
      dashboard_object.add_widget(18, view: 1, queue_id: 0, time_type: 1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, queue_id: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, queue_id: 1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshcaller_call_trend_widget_with_invalid_view
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(18, view: -1, queue_id: 0, time_type: 1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_call_trend_widget_with_invalid_queue_id
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(18, view: 1, queue_id: -1, time_type: 1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_call_trend_widget_with_invalid_source
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(18, view: 1, queue_id: 0, time_type: 1, source: 'freshcall')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_call_trend_widget_with_invalid_time_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(18, view: 1, queue_id: 0, time_type: 11, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshcaller_availability_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(13, queue_id: 0, source: 'freshcaller')
      dashboard_object.add_widget(13, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, queue_id: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, queue_id: 1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshcaller_availability_widget_with_invalid_queue_id
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(13, queue_id: -1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_availability_widget_with_invalid_source
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(13, queue_id: 0, source: 'freshcall')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshcaller_sla_trend_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(17, time_type: 1, queue_id: 0, source: 'freshcaller')
      dashboard_object.add_widget(17, time_type: 1, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, queue_id: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, queue_id: 1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshcaller_sla_trend_widget_with_invalid_queue_id
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(17, time_type: 1, queue_id: -1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_sla_trend_widget_with_invalid_source
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(17, time_type: 1, queue_id: 0, source: 'freshcall')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_sla_trend_widget_with_invalid_time_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(17, time_type: -1, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshcaller_time_trend_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 1, time_type: 1, queue_id: 0, source: 'freshcaller')
      dashboard_object.add_widget(16, metric: 1, time_type: 1, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, queue_id: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, queue_id: 1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshcaller_time_trend_widget_with_invalid_queue_id
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 1, time_type: 1, queue_id: -1, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_time_trend_widget_with_invalid_source
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 1, time_type: 1, queue_id: 0, source: 'freshcall')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_time_trend_widget_with_invalid_time_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 1, time_type: -1, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshcaller_time_trend_widget_with_invalid_matric
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: -1, time_type: 1, queue_id: 0, source: 'freshcaller')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshchat_scorecard_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(11, view: 1, source: 'freshchat')
      dashboard_object.add_widget(11, view: 1, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, view: -2 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, view: 2 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshchat_scorecard_widget_with_invalid_view
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(11, view: -1, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshchat_bar_chart_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(12, group_ids: [0], representation: 0, source: 'freshchat')
      dashboard_object.add_widget(12, group_ids: [0], representation: 0, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 201
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, representation: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, representation: 1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshchat_bar_chart_widget_with_invalid_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(12, representation: 0, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshchat_bar_chart_widget_with_invalid_representation
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(12, group_ids: [0], representation: 3, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshchat_availability_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(13, group_ids: [0], source: 'freshchat')
      dashboard_object.add_widget(13, group_ids: [0], source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, group_ids: [] }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, group_ids: [0] }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshchat_availability_widget_with_invalid_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(13, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshchat_csat_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(14, group_ids: [0], date_type: 1, source: 'freshchat')
      dashboard_object.add_widget(14, group_ids: [0], date_type: 1, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, date_type: -1 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, group_ids: [0] }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshchat_csat_widget_with_invalid_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(14, date_type: 1, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshchat_csat_widget_with_invalid_date_type
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(14, group_ids: [1], date_type: -1, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_dashboard_crud_flow_with_freshchat_time_trend_widget_with_valid_params
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 2, computation: 3, group_ids: [1], date_range: 30, source: 'freshchat')
      dashboard_object.add_widget(16, metric: 2, computation: 3, group_ids: [1], date_range: 30, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      dashboard_id = response_hash[:id]
      widget_id = response_hash[:widgets][0][:id]
      assert_response 201
      match_dashboard_response(response_hash, dashboard_object.get_dashboard_payload)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      updated_atributes = { widgets: [{ id: widget_id, computation: -3 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 400
      updated_atributes = { widgets: [{ id: widget_id, computation: 2 }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      updated_atributes = { widgets: [{ id: widget_id, deleted: true }] }
      put :update, controller_params(wrap_cname(updated_atributes).merge(id: dashboard_id, version: 'private'), false)
      assert_response 200
      delete :destroy, controller_params({ version: 'private', id: dashboard_id }, false)
      assert_response 204
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      dashboard = @account.dashboards.find_by_id(dashboard_id)
      dashboard.destroy if dashboard.present?
    end

    def test_create_dashboard_with_freshchat_time_trend_widget_with_invalid_group_ids
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 2, computation: 3, date_range: 30, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshchat_time_trend_widget_with_invalid_metric
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: -2, computation: 3, group_ids: [1], date_range: 30, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshchat_time_trend_widget_with_invalid_computation
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 2, computation: -3, group_ids: [1], date_range: 30, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_create_dashboard_with_freshchat_time_trend_widget_with_invalid_date_range
      User.any_instance.stubs(:privilege?).with(:manage_dashboard).returns(true)
      Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
      dashboard_object = DashboardObject.new(0)
      dashboard_object.add_widget(16, metric: 2, computation: 3, group_ids: [1], date_range: -30, source: 'freshchat')
      post :create, controller_params(wrap_cname(dashboard_object.get_dashboard_payload).merge!(version: 'private'), false)
      response_hash = JSON.parse(response.body).deep_symbolize_keys
      assert_response 400, response_hash
    ensure
      Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end
  end
end
