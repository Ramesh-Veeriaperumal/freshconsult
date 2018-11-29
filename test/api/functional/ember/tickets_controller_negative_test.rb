require_relative '../../test_helper'
['account_test_helper.rb', 'shared_ownership_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include AccountTestHelper
    include SharedOwnershipTestHelper
    include ApiTicketsTestHelper

    def setup
      super
    end

    # Test when group restricted agent trying to access the ticket which has not been assigned to its group
    def test_group_restricted_agent_unauthorised_ticket
      ticket = create_ticket({:status => 2})
      group_restricted_agent = add_agent_to_group(nil,
                                                  ticket_permission = 2, role_id = @account.roles.agent.first.id)
      login_as(group_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 403
    end

    # Test when restricted agent trying to access ticket which has not been assigned to him
    def test_ticket_restricted_agent_unauthorised_ticket
      ticket = create_ticket({:status => 2})
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      login_as(ticket_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 403
    end

    # Test when Internal agent has agent restricted access and he is trying to view the ticket of its group which
    # has not been assigned to him
    def test_ticket_access_by_unauthorized_internal_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id}, nil, @internal_group)
        login_as(@internal_agent)
        get :show, controller_params(version: 'private', id: ticket.display_id)
        assert_response 403
      end
    end
  end
end