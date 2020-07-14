require_relative '../../test_helper'
require_relative "#{Rails.root}/test/api/helpers/custom_dashboard/search_service_result.rb"
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')

module Ember
  class DashboardControllerTest < ::ActionController::TestCase
    include GroupHelper
    include ProductsHelper
    include DashboardTestHelper
    include DashboardRedshiftTestHelper
    include ApiTicketsTestHelper
    include SurveysTestHelper
    include SolutionsTestHelper

    def setup
      super
      @account = Account.first
      Account.stubs(:current).returns(@account)
      setup_multilingual
    end

    # ticket_summaries
    def test_scorecard_without_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :scorecard, controller_params(version: 'private')
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_scorecard_without_filter_data
      Account.first.make_current
      User.first.make_current
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      get :scorecard, controller_params(version: 'private')
      assert_response 200
      match_json(scorecard_pattern)
    end

    def test_scorecard_with_product_id
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      product = create_product
      get :scorecard, controller_params(version: 'private', product_ids: [product.id])
      assert_response 200
      User.any_instance.unstub(:privilege?)
    end

    def test_scorecard_with_product_id_not_an_array
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      product = create_product
      get :scorecard, controller_params(version: 'private', product_ids: product.id)
      assert_response 400
      match_json([bad_request_error_pattern(:product_ids, :datatype_mismatch, prepend_msg: :input_received, given_data_type: 'String', expected_data_type: 'Array')])
      User.any_instance.unstub(:privilege?)
    end

    def test_scorecard_with_product_id_not_a_number
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      get :scorecard, controller_params(version: 'private', product_ids: [Faker::Name.name])
      assert_response 400
      match_json([bad_request_error_pattern(:product_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
    end

    def test_scorecard_with_group_id_that_agent_belong
      agent = add_test_agent(@account, role: Role.where(name: 'Account Administrator').first.id)
      @controller.stubs(:current_user).returns(agent)
      group = create_group_with_agents(@account, agent_list: [agent.id])
      User.any_instance.stubs(:agent_groups).returns(group.agent_groups)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
    ensure
      User.any_instance.unstub(:agent_groups)
      @controller.unstub(:current_user)
    end

    # def test_scorecard_with_group_id_that_agent_doesnot_belong
    #   agent = add_test_agent(@account, role: Role.where(name: 'Supervisor').first.id)
    #   group_of_agent_performing = create_group_with_agents(@account, agent_list: [agent.id])
    #   group = create_group(@account)
    #   @controller.stubs(:current_user).returns(agent)
    #   User.any_instance.stubs(:agent_groups).returns(group_of_agent_performing.agent_groups)
    #   Agent.any_instance.stubs(:ticket_permission_token).returns(:group_tickets)
    #   get :scorecard, controller_params(version: 'private', group_ids: [group.id])
    #   assert_response 400
    #   match_json([bad_request_error_pattern(:group_ids, :inaccessible_value, resource: :group, attribute: :group_ids)])
    #   User.any_instance.unstub(:agent_groups)
    #   Agent.any_instance.unstub(:ticket_permission_token)
    #   @controller.unstub(:current_user)
    # end

    def test_scorecard_for_supervisor_with_global_access_and_no_associated_groups
      agent = add_test_agent(@account, role: Role.where(name: 'Supervisor').first.id)
      group = create_group(@account)
      @controller.stubs(:current_user).returns(agent)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
      @controller.unstub(:current_user)
    end

    def test_scorecard_for_admin
      agent = add_test_agent(@account, role: Role.where(name: 'Administrator').first.id)
      group = create_group(@account)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      @controller.stubs(:current_user).returns(agent)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
      @controller.unstub(:current_user)
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
    end

    def test_scorecard_with_group_id_not_a_number
      get :scorecard, controller_params(version: 'private', group_ids: [Faker::Name.name])
      assert_response 400
      match_json([bad_request_error_pattern(:group_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
    end

    def test_scorecard_with_group_id_not_an_array
      agent = add_test_agent(@account, role: Role.where(name: 'Administrator').first.id)
      group = create_group(@account)
      @controller.stubs(:current_user).returns(agent)
      get :scorecard, controller_params(version: 'private', group_ids: group.id)
      assert_response 400
      match_json([bad_request_error_pattern(:group_ids, :datatype_mismatch, prepend_msg: :input_received, given_data_type: 'String', expected_data_type: 'Array')])
      @controller.unstub(:current_user)
    end

    # Show
    def test_show_without_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_show_without_access_to_solutions_dashboard
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
      get :show, controller_params(version: 'private', id: 2)
      assert_response 403
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_solutions_dashboard
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2)
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_solutions_dashboard_with_language_code
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)      
      get :show, controller_params(version: 'private', id: 2, language: Account.current.language)
      assert !get_widget_names.include?('outdated')
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_solutions_dashboard_with_secondary_language
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2, language: Account.current.supported_languages.first)
      assert get_widget_names.include?('outdated')
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_solutions_dashboard_without_article_approval_workflow
      Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2, language: Account.current.supported_languages.first)
      assert !get_widget_names.include?('in_review')
      assert !get_widget_names.include?('approved')
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      Account.any_instance.unstub(:article_approval_workflow_enabled?)
    end

    def test_show_solutions_dashboard_with_article_approval_workflow
      Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2, language: Account.current.supported_languages.first)
      assert get_widget_names.include?('in_review')
      assert get_widget_names.include?('approved')
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      Account.any_instance.unstub(:article_approval_workflow_enabled?)
    end

    def test_show_solutions_dashboard_with_article_approval_workflow_without_approval_privilege
      Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      get :show, controller_params(version: 'private', id: 2, language: Account.current.supported_languages.first)
      assert get_widget_names.include?('in_review')
      assert get_widget_names.include?('approved')
      assert !get_widget_names.include?('approval_pending_articles')
      assert_response 200
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      Account.any_instance.unstub(:article_approval_workflow_enabled?)
    end

    def test_show_solutions_dashboard_with_secondary_language_without_multilingual
      Account.any_instance.stubs(:multilingual?).returns(false)
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2, language: Account.current.supported_languages.first)
      assert_response 404
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
      Account.any_instance.unstub(:multilingual?)
    end

    def test_show_with_manage_ticket_access_to_solutions_dashboard
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2)
      assert_response 403
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_with_solution_privilege_access_to_default_dashboard
      Account.any_instance.stubs(:solutions_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
      User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
      get :show, controller_params(version: 'private', id: 2)
      assert_response 403
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
    end

    def test_show_with_omni_channel_dashboard_enabled_and_user_has_view_reports_privilege
      Account.any_instance.stubs(:omni_channel_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
      assert_equal get_widget_names, ApiDashboardConstants::OMNI_CHANNEL_DASHBOARD.dup.map(&:first)
      match_json(omni_channel_pattern)
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_with_omni_channel_dashboard_enabled_and_user_has_not_view_reports_privilege
      Account.any_instance.stubs(:omni_channel_dashboard_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
      assert_not_equal get_widget_names, ApiDashboardConstants::OMNI_CHANNEL_DASHBOARD.dup.map(&:first)
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_with_omni_channel_dashboard_not_enabled_and_user_has_view_reports_privilege
      Account.any_instance.stubs(:omni_channel_dashboard_enabled?).returns(false)
      User.any_instance.stubs(:privilege?).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
      assert_not_equal get_widget_names, ApiDashboardConstants::OMNI_CHANNEL_DASHBOARD.dup.map(&:first)
    ensure
      Account.any_instance.unstub(:solutions_dashboard_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    def test_show_unresolved_tickets_widget_for_sprout_feature
      Subscription.any_instance.stubs(:sprout_plan?).returns(true)
      Account.any_instance.stubs(:unresolved_tickets_widget_for_sprout_enabled?).returns(true)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
      widgets = JSON.parse(response.body)['widgets']
      assert_equal widgets.count { |widget| widget['name'] == 'unresolved-tickets' }, 1
      Subscription.any_instance.unstub(:sprout_plan?)
      Account.any_instance.unstub(:unresolved_tickets_widget_for_sprout_enabled?)
    end

    def test_unresolved_tickets_widget_for_sprout_feature_for_agent
      Subscription.any_instance.stubs(:sprout_plan?).returns(true)
      Account.any_instance.stubs(:unresolved_tickets_widget_for_sprout_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      get :show, controller_params(version: 'private', id: 1)
      assert_response 200
      widgets = JSON.parse(response.body)['widgets']
      assert_equal widgets.count { |widget| widget['name'] == 'unresolved-tickets' }, 0
      Subscription.any_instance.unstub(:sprout_plan?)
      Account.any_instance.unstub(:unresolved_tickets_widget_for_sprout_enabled?)
      User.any_instance.unstub(:privilege?)
    end

    # satisfaction_survey

    def test_satisfaction_survey_without_active_survey
      Account.any_instance.stubs(:any_survey_feature_enabled_and_active?).returns(false)
      get :survey_info, controller_params(version: 'private')
      assert_response 403
      Account.any_instance.unstub(:any_survey_feature_enabled_and_active?)
    end

    def test_satisfaction_survey
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      get :survey_info, controller_params(version: 'private')
      assert_response 200
      match_json(survey_info_pattern(is_agent: false))
      User.any_instance.stubs(:privilege?)
    end

    def test_satisfaction_survey_with_group_filter
      group = create_group(@account)
      ticket = create_ticket(group: group)
      4.times do
        create_survey_result(ticket, 3)
      end
      get :survey_info, controller_params(version: 'private', group_id: group.id)
      assert_response 200
      match_json(survey_info_pattern(group_id: group.id, is_agent: false))
    end

    def test_satisfaction_survey_with_multi_group_filter
      group1 = create_group(@account)
      group2 = create_group(@account)
      ticket1 = create_ticket(group: group1)
      ticket2 = create_ticket(group: group2)
      4.times do
        create_survey_result(ticket1, 3)
      end
      2.times do
        create_survey_result(ticket2, 3)
      end
      get :survey_info, controller_params(version: 'private', group_ids: [group1.id, group2.id])
      assert_response 200
      match_json(survey_multi_group_pattern(group_ids: [group1.id, group2.id], is_agent: false))
    end

    def test_satisfaction_survey_without_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :survey_info, controller_params(version: 'private')
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_satisfaction_survey_without_feature
      Account.any_instance.stubs(:any_survey_feature_enabled_and_active?).returns(false)
      @account.features.surveys.destroy
      @account.features.survey_links.destroy
      @account.revoke_feature(:surveys)
      @account.reload
      get :survey_info, controller_params(version: 'private')
      assert_response 403
    ensure
      @account.features.surveys.create
      @account.features.survey_links.create
      @account.add_feature(:surveys)
    end

    # Forum moderation

    def test_moderation_count_without_privilege_to_delete_topic
      User.any_instance.stubs(:privilege?).with(:delete_topic).returns(false)
      get :moderation_count, controller_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_moderation_count_without_feature
      @account.features.forums.destroy
      @account.revoke_feature(:forums)
      @account.reload
      get :moderation_count, controller_params(version: 'private')
      assert_response 403
    ensure
      @account.features.forums.create
      @account.add_feature(:forums)
    end

    def test_moderation_count
      get :moderation_count, controller_params(version: 'private')
      assert_response 200
      match_json(moderation_count_pattern)
    end

    # Unresolved tickets

    def test_unresolved_tickets_widget_with_group_filter
      group = create_group(@account)
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, group_ids: [group.id], group_by: 'group_id')
      assert_response 200
      match_json(unresolved_tickets_pattern(widget: 1, group_ids: [group.id], group_by: 'group_id'))
    end

    def test_unresolved_tickets_widget_with_product_filter
      product = create_product()
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, product_ids: [product.id], group_by: 'group_id')
      assert_response 200
      match_json(unresolved_tickets_pattern(widget: 1, product_ids: [product.id], group_by: 'group_id'))
    end

    def test_unresolved_tickets_widget_without_filter
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, group_by: 'group_id', status_ids: [2])
      assert_response 200
      match_json(unresolved_tickets_pattern(widget: 1, group_by: 'group_id', status_ids: [2]))
    end

    def test_unresolved_tickets_detailed_page_without_filter
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'responder_id')
      assert_response 200
      match_json(unresolved_tickets_pattern(group_by: 'responder_id'))
    end

    def test_unresolved_tickets_detailed_page_with_filter
      groups = []
      create_groups(@account).each { |group| groups << group.id }
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'group_id', group_ids: groups)
      assert_response 200
      match_json(unresolved_tickets_pattern(group_by: 'group_id', group_ids: groups))
    end

    # def test_unresolved_tickets_with_group_id_not_in_db
    #   group = (Group.maximum(:id) || 0).to_i + 50
    #   get :unresolved_tickets_data, controller_params(version: 'private', widget: true, group_by: 'group_id', group_ids: [group], status_ids: [2])
    #   assert_response 400
    # end

    # def test_unresolved_tickets_with_responder_id_not_in_db
    #   responder = (Agent.maximum(:user_id) || 0).to_i + 80
    #   get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'responder_id', responder_ids: [responder])
    #   assert_response 400
    # end

    # def test_unresolved_tickets_with_status_not_in_db
    #   status = (Helpdesk::TicketStatus.maximum(:id) || 0).to_i + 50
    #   get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'group_id', status_ids: [2, 4, 872, status])
    #   assert_response 400
    # end

    def test_unresolved_tickets_with_invalid_group_by_values
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'requester_id')
      assert_response 400
      pattern = bad_request_error_pattern('group_by', :not_included, list: 'group_id,responder_id,internal_group_id,internal_agent_id')
      match_json [pattern]
    end

    def test_unresolved_tickets_without_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'group_id')
      assert_response 403
    ensure
      User.any_instance.unstub(:privilege?)
    end

    # Ticket trends and metrics

    def test_ticket_trends_valid_request
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        User.any_instance.stubs(:time_zone).returns(dashboard_timezone)
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_trends, controller_params(version: 'private')
        assert_response 200
        match_json(dashboard_trends_parsed_response)
      end
    ensure
      User.any_instance.unstub(:time_zone)
    end

    def test_ticket_metrics_valid_request
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_metrics, controller_params(version: 'private')
        assert_response 200
        match_json(dashboard_metrics_parsed_response)
      end
    end

    def test_ticket_trends_during_downtime
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_redshift_failure_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_trends, controller_params(version: 'private')
        assert_response 503
      end
    end

    def test_ticket_metrics_during_downtime
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_redshift_failure_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_metrics, controller_params(version: 'private')
        assert_response 503
      end
    end

    def test_ticket_trends_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_trends, controller_params(version: 'private')
        assert_response 403
      end
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_ticket_metrics_access_to_dashboard
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_metrics, controller_params(version: 'private')
        assert_response 403
      end
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_ticket_trends_without_valid_group_id_format
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_trends, controller_params(version: 'private', group_ids: ['hello'])
        assert_response 400
      end
    end

    def test_ticket_metrics_without_valid_group_id_format
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_metrics, controller_params(version: 'private', group_ids: ['hello'])
        assert_response 400
      end
    end

    def test_ticket_trends_without_valid_product_id_format
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_trends, controller_params(version: 'private', product_ids: ['hello'])
        assert_response 400
      end
    end

    def test_ticket_metrics_without_valid_product_id_format
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        get :ticket_metrics, controller_params(version: 'private', product_ids: ['hello'])
        assert_response 400
      end
    end

    def test_ticket_trends_with_valid_product_id
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        User.any_instance.stubs(:time_zone).returns(dashboard_timezone)
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        product = create_product
        get :ticket_trends, controller_params(version: 'private', product_ids: [product.id])
        assert_response 200
      end
    ensure
      User.any_instance.unstub(:time_zone)
    end

    def test_ticket_metrics_with_valid_product_id
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        product = create_product
        get :ticket_metrics, controller_params(version: 'private', product_ids: [product.id])
        assert_response 200
      end
    end

    def test_ticket_trends_with_valid_group_id
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_trends_data
        User.any_instance.stubs(:time_zone).returns(dashboard_timezone)
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        group = create_group(@account)
        get :ticket_trends, controller_params(version: 'private', group_ids: [group.id])
        assert_response 200
      end
    ensure
      User.any_instance.unstub(:time_zone)
    end

    def test_tticket_metrics_with_valid_group_id
      Timecop.freeze(dashboard_redshift_current_time) do
        stub_data = dashboard_metrics_data
        ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
        group = create_group(@account)
        get :ticket_metrics, controller_params(version: 'private', group_ids: [group.id])
        assert_response 200
      end
    end

    # def test_ticket_trends_with_invalid_product_id
    #   Timecop.freeze(dashboard_redshift_current_time) do
    #     stub_data = dashboard_trends_data
    #     ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
    #     product = create_product
    #     get :ticket_trends, controller_params(version: 'private', product_ids: [product.id + 100])
    #     assert_response 400
    #   end
    # end

    # def test_ticket_metrics_with_invalid_product_id
    #   Timecop.freeze(dashboard_redshift_current_time) do
    #     stub_data = dashboard_metrics_data
    #     ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
    #     product = create_product
    #     get :ticket_metrics, controller_params(version: 'private', product_ids: [product.id + 100])
    #     assert_response 400
    #   end
    # end

    # def test_ticket_trends_with_invalid_group_id
    #   Timecop.freeze(dashboard_redshift_current_time) do
    #     stub_data = dashboard_trends_data
    #     ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
    #     group = create_group(@account)
    #     get :ticket_trends, controller_params(version: 'private', group_ids: [group.id + 100])
    #     assert_response 400
    #   end
    # end

    # def test_ticket_metrics_with_invalid_group_id
    #   Timecop.freeze(dashboard_redshift_current_time) do
    #     stub_data = dashboard_metrics_data
    #     ::Dashboard::RedshiftRequester.any_instance.stubs(:fetch_records).returns(stub_data)
    #     group = create_group(@account)
    #     get :ticket_metrics, controller_params(version: 'private', group_ids: [group.id + 100])
    #     assert_response 400
    #   end
    # end

        # search service related tests
    def test_scorecard_without_filter_data_search_service
      Account.first.make_current
      User.first.make_current
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(false)
      Account.current.launch(:count_service_es_reads)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :scorecard, controller_params(version: 'private')
      assert_response 200
      match_json(scorecard_pattern_search_service(stub_data))
    ensure
      User.any_instance.unstub(:privilege?)
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_scorecard_with_product_id_search_service
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      User.any_instance.stubs(:privilege?).with(:view_reports).returns(true)
      product = create_product
      Account.current.launch(:count_service_es_reads)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :scorecard, controller_params(version: 'private', product_ids: [product.id])
      assert_response 200
      match_json(scorecard_pattern_search_service(stub_data))
    ensure
      User.any_instance.unstub(:privilege?)
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_scorecard_with_group_id_that_agent_belong_search_service
      agent = add_test_agent(@account, role: Role.where(name: 'Account Administrator').first.id)
      @controller.stubs(:current_user).returns(agent)
      group = create_group_with_agents(@account, agent_list: [agent.id])
      User.any_instance.stubs(:agent_groups).returns(group.agent_groups)
      Account.current.launch(:count_service_es_reads)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
      match_json(scorecard_pattern_search_service(stub_data))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      User.any_instance.unstub(:agent_groups)
      @controller.unstub(:current_user)
    end

    def test_scorecard_for_supervisor_with_global_access_and_no_associated_groups_search_service
      agent = add_test_agent(@account, role: Role.where(name: 'Supervisor').first.id)
      group = create_group(@account)
      @controller.stubs(:current_user).returns(agent)
      Account.current.launch(:count_service_es_reads)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
      match_json(scorecard_pattern_search_service(stub_data))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      @controller.unstub(:current_user)
    end

    def test_scorecard_for_admin_search_service
      agent = add_test_agent(@account, role: Role.where(name: 'Administrator').first.id)
      group = create_group(@account)
      @controller.stubs(:current_user).returns(agent)
      Account.current.launch(:count_service_es_reads)
      stub_data = scorecard_stub_data
      SearchService::Client.any_instance.stubs(:multi_aggregate).returns(stub_data)
      get :scorecard, controller_params(version: 'private', group_ids: [group.id])
      assert_response 200
      match_json(scorecard_pattern_search_service(stub_data))
    ensure
      SearchService::Client.any_instance.unstub(:multi_aggregate)
      Account.current.rollback(:count_service_es_reads)
      @controller.unstub(:current_user)
    end

    def test_unresolved_tickets_widget_with_group_filter_search_service
      group = create_group(@account)
      Account.current.launch(:count_service_es_reads)
      stub_data = unreloved_tickets_stub_data(group_ids: [group.id], group_by: 'group_id')
      SearchService::Client.any_instance.stubs(:aggregate).returns(stub_data)
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, group_ids: [group.id], group_by: 'group_id')
      assert_response 200
    ensure
      SearchService::Client.any_instance.unstub(:aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_unresolved_tickets_widget_with_product_filter_search_service
      product = create_product()
      Account.current.launch(:count_service_es_reads)
      stub_data = unreloved_tickets_stub_data(product_ids: [product.id], group_by: 'group_id')
      SearchService::Client.any_instance.stubs(:aggregate).returns(stub_data)
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, product_ids: [product.id], group_by: 'group_id')
      assert_response 200
    ensure
      SearchService::Client.any_instance.unstub(:aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_unresolved_tickets_widget_without_filter_search_service
      Account.current.launch(:count_service_es_reads)
      stub_data = unreloved_tickets_stub_data(group_by: 'group_id', status_ids: [2])
      SearchService::Client.any_instance.stubs(:aggregate).returns(stub_data)
      get :unresolved_tickets_data, controller_params(version: 'private', widget: 1, group_by: 'group_id', status_ids: [2])
      assert_response 200
    ensure
      SearchService::Client.any_instance.unstub(:aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_unresolved_tickets_detailed_page_without_filter_search_service
      Account.current.launch(:count_service_es_reads)
      stub_data = unreloved_tickets_stub_data(group_by: 'responder_id')
      SearchService::Client.any_instance.stubs(:aggregate).returns(stub_data)
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'responder_id')
      assert_response 200
    ensure
      SearchService::Client.any_instance.unstub(:aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    def test_unresolved_tickets_detailed_page_with_filter_search_service
      groups = []
      create_groups(@account).each { |group| groups << group.id }
      Account.current.launch(:count_service_es_reads)
      stub_data = unreloved_tickets_stub_data(group_by: 'group_id', group_ids: groups)
      SearchService::Client.any_instance.stubs(:aggregate).returns(stub_data)
      get :unresolved_tickets_data, controller_params(version: 'private', group_by: 'group_id', group_ids: groups)
      assert_response 200
    ensure
      SearchService::Client.any_instance.unstub(:aggregate)
      Account.current.rollback(:count_service_es_reads)
    end

    private

      def get_widget_names
        JSON.parse(response.body)['widgets'].map {|widget| widget['name']}
      end
  end
end
