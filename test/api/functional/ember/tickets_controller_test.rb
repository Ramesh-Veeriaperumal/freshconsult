require_relative '../../test_helper'
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include ScenarioAutomationsTestHelper

    def wrap_cname(params)
      { ticket: params }
    end

    def ticket_params_hash
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def test_bulk_delete_with_no_params
      put :bulk_delete, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_delete_with_invalid_ids
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      invalid_ids = [ticket_ids[0] + 20, ticket_ids[0] + 30]
      ids_to_delete = [*ticket_ids, *invalid_ids]
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
      assert_response 202
    end

    def test_bulk_delete_with_valid_ids
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
      assert_response 204
    end

    def test_bulk_delete_with_errors_in_deletion
      tickets = []
      rand(2..10).times do
        tickets << create_ticket(ticket_params_hash)
      end
      ids_to_delete = tickets.map(&:display_id)
      Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
      Helpdesk::Ticket.any_instance.unstub(:save)
      failures = {}
      ids_to_delete.each { |id| failures[id] = { :id => :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_delete_tickets_without_access
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?)
      failures = {}
      ticket_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_delete_tickets_with_group_access
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
      group = create_group_with_agents(@account, agent_list: [@agent.id])
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash.merge(group_id: group.id)).display_id
      end
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      assert_response 204
    end

    def test_bulk_delete_tickets_with_assigned_access
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
      Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      Helpdesk::Ticket.any_instance.unstub(:responder_id)
      assert_response 204
    end

    def test_bulk_spam_with_no_params
      put :bulk_spam, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_spam_with_invalid_ids
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      invalid_ids = [ticket_ids[0] + 20, ticket_ids[0] + 30]
      ids_list = [*ticket_ids, *invalid_ids]
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ids_list})
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
      assert_response 202
    end

    def test_bulk_spam_with_valid_ids
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
      assert_response 204
    end

    def test_bulk_spam_with_errors
      tickets = []
      rand(2..10).times do
        tickets << create_ticket(ticket_params_hash)
      end
      ids_list = tickets.map(&:display_id)
      Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ids_list})
      Helpdesk::Ticket.any_instance.unstub(:save)
      failures = {}
      ids_list.each { |id| failures[id] = { :id => :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_spam_tickets_without_access
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?)
      failures = {}
      ticket_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_spam_tickets_with_group_access
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
      group = create_group_with_agents(@account, agent_list: [@agent.id])
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash.merge(group_id: group.id)).display_id
      end
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      assert_response 204
    end

    def test_bulk_spam_tickets_with_assigned_access
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
      Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      Helpdesk::Ticket.any_instance.unstub(:responder_id)
      assert_response 204
    end

    def test_execute_scenario
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, controller_params(version: 'private', id: ticket_id, scenario_id: scenario_id)
      assert_response 204
    end

    def test_execute_scenario_with_invalid_ticket_id
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id + 20
      put :execute_scenario, controller_params(version: 'private', id: ticket_id, scenario_id: scenario_id)
      assert_response 404
    end

    def test_execute_scenario_without_ticket_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      put :execute_scenario, controller_params(version: 'private', id: ticket_id, scenario_id: scenario_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
    end

    def test_execute_scenario_without_scenario_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      ScenarioAutomation.any_instance.stubs(:check_user_privilege).returns(false)
      put :execute_scenario, controller_params(version: 'private', id: ticket_id, scenario_id: scenario_id)
      ScenarioAutomation.any_instance.unstub(:check_user_privilege)
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :"is invalid")])
    end

    def test_bulk_execute_scenario_with_invalid_ticket_ids
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      invalid_ids = [ticket_ids[0] + 20, ticket_ids[0] + 30]
      id_list = [*ticket_ids, *invalid_ids]
      put :bulk_execute_scenario, construct_params({ version: 'private', scenario_id: scenario_id }, { ids: id_list })
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
      assert_response 202
    end

    def test_bulk_execute_scenario_with_valid_ids
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_execute_scenario, construct_params({ version: 'private', scenario_id: scenario_id }, { ids: ticket_ids })
      assert_response 202
    end

    def test_spam_with_invalid_ticket_id
      put :spam, construct_params({ version: 'private' }, false).merge(id: 0)
      assert_response 404
    end

    def test_spam_with_unauthorized_ticket_id
      @sample_ticket = create_ticket
      User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
      User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
      User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
      put :spam, construct_params({ version: 'private' }, false).merge(id: @sample_ticket.id)
      User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_spam_with_valid_ticket_id
      @sample_ticket = create_ticket
      assert !@sample_ticket.spam?
      put :spam, construct_params({ version: 'private' }, false).merge(id: @sample_ticket.id)
      assert_response 204
      assert @sample_ticket.reload.spam?
    end
  end
end
