require_relative '../../test_helper'
module Ember
  class SubscriptionsControllerTest < ActionController::TestCase
    include TicketHelper

    def wrap_cname(params)
      { subscription: params }
    end

    def test_watch_ticket_with_invalid_ticket_id
      ticket = create_ticket
      post :watch, construct_params({version: 'private', id: ticket.id + 10}, {})
      assert_response 404
    end

    def test_watch_ticket_default
      ticket = create_ticket
      post :watch, construct_params({version: 'private', id: ticket.id}, {})
      assert_response 204
      assert ticket.subscriptions.count == 1
      latest_subscription = ticket.subscriptions.last
      assert_equal User.current.id, latest_subscription.user_id
    end

    def test_watch_ticket_with_invalid_user_id
      ticket = create_ticket
      params_hash = { user_id: @agent.id + 100 }
      post :watch, construct_params({version: 'private', id: ticket.id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
    end

    def test_watch_ticket
      ticket = create_ticket
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      params_hash = { user_id: agent.id }
      post :watch, construct_params({version: 'private', id: ticket.id}, params_hash)
      assert_response 204
      assert ticket.subscriptions.count == 1
      latest_subscription = ticket.subscriptions.last
      assert_equal agent.id, latest_subscription.user_id
    end

    def test_unwatch_ticket_with_no_watchers
      ticket = create_ticket
      put :unwatch, controller_params(version: 'private', id: ticket.id)
      assert_response 404
    end

    def test_unwatch_ticket_with_invalid_ticket_id
      ticket = create_ticket
      put :unwatch, controller_params(version: 'private', id: ticket.id + 10)
      assert_response 404
    end

    def test_unwatch_ticket_with_params
      ticket = create_ticket
      params_hash = { user_id: User.current.id }
      put :unwatch, construct_params({ version: 'private', id: ticket.id }, params_hash)
      assert_response 400
      match_json(request_error_pattern(:no_content_required))
    end

    def test_unwatch_ticket
      ticket = create_ticket
      ticket.subscriptions.build(user_id: User.current.id)
      ticket.save
      assert ticket.subscriptions.count == 1
      put :unwatch, controller_params(version: 'private', id: ticket.id)
      assert_response 204
      assert ticket.subscriptions.count == 0
    end

    def test_list_watchers
      ticket = create_ticket
      ticket.subscriptions.build(user_id: User.current.id)
      ticket.save
      get :watchers, controller_params(version: 'private', id: ticket.id)
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    end
  end
end
