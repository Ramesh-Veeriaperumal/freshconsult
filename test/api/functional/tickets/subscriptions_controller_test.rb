require_relative '../../test_helper'
['group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Tickets
  class SubscriptionsControllerTest < ActionController::TestCase
    include TicketHelper
    include ApiTicketsTestHelper
    include GroupHelper

    BULK_TICKET_CREATE_COUNT = 2

    def wrap_cname(params)
      { subscription: params }
    end

    @@initial_setup_run = false

    def setup
      super
      initial_setup
    end

    def initial_setup
      return if @@initial_setup_run
      @account.add_feature(:add_watcher) unless @account.has_feature?(:add_watcher)
      @account.reload
      @@initial_setup_run = true
    end

    def test_watch_without_feature
      @account.revoke_feature(:add_watcher)
      ticket = create_ticket
      post :watch, construct_params({ id: ticket.display_id }, {})
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Add Watcher'))
    ensure
      @account.add_feature(:add_watcher)
    end

    def test_watch_ticket_with_invalid_ticket_id
      ticket = create_ticket
      post :watch, construct_params({ id: ticket.display_id + 10 }, {})
      assert_response 404
    end

    def test_watch_ticket_default
      ticket = create_ticket
      post :watch, construct_params({ id: ticket.display_id }, {})
      assert_response 204
      assert ticket.subscriptions.count == 1
      latest_subscription = ticket.subscriptions.last
      assert_equal User.current.id, latest_subscription.user_id
    end

    def test_watch_ticket_with_invalid_user_id
      ticket = create_ticket
      params_hash = { user_id: @agent.id + 10_000 }
      post :watch, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
    end

    def test_watch_spam_ticket
      ticket = create_ticket(spam: true)
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      params_hash = { user_id: agent.id }
      post :watch, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 404
    end

    def test_watch_ticket
      ticket = create_ticket
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      params_hash = { user_id: agent.id }
      post :watch, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 204
      assert ticket.subscriptions.count == 1
      latest_subscription = ticket.subscriptions.last
      assert_equal agent.id, latest_subscription.user_id
    end

    def test_unwatch_without_feature
      @account.revoke_feature(:add_watcher)
      ticket = create_ticket
      put :unwatch, controller_params(id: ticket.display_id)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Add Watcher'))
    ensure
      @account.add_feature(:add_watcher)
    end

    def test_unwatch_ticket_with_no_watchers
      ticket = create_ticket
      put :unwatch, controller_params(id: ticket.display_id)
      assert_response 404
    end

    def test_unwatch_ticket_with_invalid_ticket_id
      ticket = create_ticket
      put :unwatch, controller_params(id: ticket.display_id + 10)
      assert_response 404
    end

    def test_unwatch_ticket_with_params
      ticket = create_ticket
      params_hash = { user_id: User.current.id }
      put :unwatch, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 400
      match_json(request_error_pattern(:no_content_required))
    end

    def test_unwatch_spam_ticket
      ticket = create_ticket(spam: true)
      ticket.subscriptions.build(user_id: User.current.id)
      ticket.save
      put :unwatch, controller_params(id: ticket.display_id)
      assert_response 404
    end

    def test_unwatch_ticket
      ticket = create_ticket
      ticket.subscriptions.build(user_id: User.current.id)
      ticket.save
      assert ticket.subscriptions.count == 1
      put :unwatch, controller_params(id: ticket.display_id)
      assert_response 204
      assert ticket.subscriptions.count == 0
    end

    def test_list_watchers_without_feature
      @account.revoke_feature(:add_watcher)
      ticket = create_ticket
      get :watchers, controller_params(id: ticket.display_id)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Add Watcher'))
    ensure
      @account.add_feature(:add_watcher)
    end

    def test_list_watchers
      ticket = create_ticket
      ticket.subscriptions.build(user_id: User.current.id)
      ticket.save
      get :watchers, controller_params(id: ticket.display_id)
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    end

    def test_bulk_watch_without_feature
      @account.revoke_feature(:add_watcher)
      ticket = create_ticket
      params_hash = { ids: [ticket.display_id], user_id: @agent.id }
      post :bulk_watch, construct_params({}, params_hash)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Add Watcher'))
    ensure
      @account.add_feature(:add_watcher)
    end

    def test_bulk_watch_with_no_params
      put :bulk_watch, construct_params({})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_watch_with_invalid_user_id
      ticket_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
      params_hash = { ids: ticket_ids, user_id: @agent.id + 10_000 }
      post :bulk_watch, construct_params({}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
    end

    def test_bulk_watch_with_valid_user_id
      ticket_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      params_hash = { ids: ticket_ids, user_id: agent.id }
      put :bulk_watch, construct_params({}, params_hash)
      assert_response 204
    end

    def test_bulk_watch_failure
      ticket_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
      params_hash = { ids: ticket_ids }
      Helpdesk::Subscription.any_instance.stubs(:save).returns(false)
      put :bulk_watch, construct_params({}, params_hash)
      Helpdesk::Subscription.any_instance.unstub(:save)
      assert_response 202
      failures = {}
      ticket_ids.each { |id| failures[id] = {} }
      match_json(partial_success_response_pattern([], failures))
    end

    def test_bulk_watch
      ticket_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
      spam_ticket = create_ticket(spam: true)
      invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20, spam_ticket.display_id]
      params_hash = {  ids: [*ticket_ids, *invalid_ids] }
      put :bulk_watch, construct_params({}, params_hash)
      assert_response 202
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
    end

    def test_bulk_unwatch_without_feature
      @account.revoke_feature(:add_watcher)
      ticket = create_ticket
      put :bulk_unwatch, construct_params({}, {ids: [ticket.display_id]})
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Add Watcher'))
    ensure
      @account.add_feature(:add_watcher)
    end

    def test_bulk_unwatch_with_no_params
      put :bulk_unwatch, construct_params({})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_unwatch_failure
      ticket_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
      params_hash = {  ids: ticket_ids }
      put :bulk_unwatch, construct_params({}, params_hash)
      assert_response 202
      failures = {}
      ticket_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
    end

    def test_bulk_unwatch
      ticket_ids = []
      BULK_TICKET_CREATE_COUNT.times do
        ticket = create_ticket
        ticket.subscriptions.build(user_id: User.current.id)
        ticket.save
        ticket_ids << ticket.display_id
      end
      params_hash = {  ids: ticket_ids }
      put :bulk_unwatch, construct_params({}, params_hash)
      assert_response 204
    end

    def test_bulk_watch_with_valid_user_id_with_read_scope
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group1 = create_group_with_agents(@account, agent_list: [agent.id])
      group2 = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group1.id).first
      agent_group.write_access = false
      agent_group.save!
      ticket1 = create_ticket({}, group1)
      ticket2 = create_ticket({}, group2)
      ticket_ids = [ticket1.display_id, ticket2.display_id]
      login_as(agent)
      params_hash = { ids: ticket_ids, user_id: agent.id }
      put :bulk_watch, construct_params({}, params_hash)
      assert_response 202
      failures = {}
      failure_ticket_ids = [ticket1.display_id]
      success_ticket_ids = [ticket2.display_id]
      failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
      match_json(partial_success_response_pattern(success_ticket_ids, failures))
    ensure
      group1.destroy if group1.present?
      group2.destroy if group2.present?
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end

    def test_bulk_unwatch_with_valid_user_id_with_read_scope
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group1 = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group1.id).first
      agent_group.write_access = false
      agent_group.save!
      ticket_ids = []
      BULK_TICKET_CREATE_COUNT.times do
        ticket = create_ticket
        ticket.subscriptions.build(user_id: User.current.id)
        ticket.group_id = group1.id
        ticket.save
        ticket_ids << ticket.display_id
      end
      params_hash = { ids: ticket_ids }
      login_as(agent)
      put :bulk_unwatch, construct_params({}, params_hash)
      assert_response 202
    ensure
      group1.destroy if group1.present?
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end
end
